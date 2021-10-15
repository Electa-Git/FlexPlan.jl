"""
Abstract type for Benders decomposition algorithms.

All concrete types shall have the following fields:
- `max_iter`: maximum number of iterations before stopping. Default: 1000.
- `tightening_rtol`: add an optimality cut only if `(sp_obj-sp_obj_lb)/abs(sp_obj) > tightening_rtol`, where `sp_obj` is the objective function value of the secondary problem and and `sp_obj_lb` is the value of the corresponding surrogate function. Default: `sqrt(eps())`.
- `sp_obj_lb_min`: constant term of the initial optimality cut, which prevents the main problem from being unbounded at the beginning. Default: `-1e12`."
- `silent`: require the solvers to produce no output; take precedence over any other attribute controlling verbosity. Default: `true`.
"""
abstract type BendersAlgorithm end

"A macro for adding the standard fields to a concrete BendersAlgorithm type"
_IM.@def benders_fields begin
    max_iter::Int
    tightening_rtol::Float64
    sp_obj_lb_min::Float64
    silent::Bool
end

"""
    run_benders_decomposition(algo, data, model_type, main_opt, sec_opt, main_bm, sec_bm, <keyword arguments>)

Run Benders decomposition on `data` using the network model type `model_type`.

The algorithm implementation is specified by `algo` (see methods documentation).

Main and secondary problems are generated through `main_bm` and `sec_bm` build methods and
iteratively solved by `main_opt` and `sec_opt` optimizers.
The main problem must be formulated in such a way that, when at each iteration some of the
variables of the secondary problems are fixed at the values given by the current optimal
solution of the main problem, secondary problems are feasible.

# Arguments
- `ref_extensions::Vector{<:Function} = Function[]`: reference extensions, used to
  instantiate both main and secondary problems.
- `solution_processors::Vector{<:Function} = Function[]`: solution processors, applied to
  solutions of secondary problems.
- `kwargs...`: passed to `PowerModels.instantiate_model()` when building main and secondary
  problems.

# Implementation
The objective function in `main_bm` must contain only the investment-related terms
(auxiliary variables for Benders optimality cuts are added later).
"""
function run_benders_decomposition end


## Utility functions

function combine_sol_dict!(d::AbstractDict, other::AbstractDict, atol=1e-6, path="")
    for (k,v) in other
        if haskey(d, k)
            combine_sol_dict!(d[k], other[k], atol, "$path : $k")
        else
            d[k] = v
        end
    end
    return d
end

function combine_sol_dict!(d::Number, other::Number, atol=1e-6, path="")
    if isapprox(d, other; atol)
        return d
    else
        Memento.error(_LOGGER, "Different values found while combining dicts at path \"$(path[4:end])\": $d, $other.")
    end
end

function combine_sol_dict!(d, other, atol=1e-6, path="")
    if d == other
        return d
    else
        Memento.error(_LOGGER, "Different values found while combining dicts at path \"$(path[4:end])\": $d, $other.")
    end
end


## Common auxiliary functions

function instantiate_model(algo, data, model_type, main_opt, sec_opt, main_bm, sec_bm; ref_extensions, kwargs...)
    _FP.require_dim(data, :scenario, :year)
    scen_year_ids = [(s,y) for y in 1:_FP.dim_length(data, :year) for s in 1:_FP.dim_length(data, :scenario)]
    num_sp = length(scen_year_ids) # Number of secondary problems

    pm_main = _PM.instantiate_model(data, model_type, main_bm; ref_extensions, kwargs...)
    JuMP.set_optimizer(pm_main.model, main_opt)
    if algo.silent
        JuMP.set_silent(pm_main.model)
    end
    sp_obj_lb_var = JuMP.@variable(pm_main.model, [p=1:num_sp], lower_bound=algo.sp_obj_lb_min)
    JuMP.@objective(pm_main.model, Min, JuMP.objective_function(pm_main.model) + sum(sp_obj_lb_var))

    pm_sec = Vector{model_type}(undef, num_sp)
    Threads.@threads for i in 1:num_sp
        s, y = scen_year_ids[i]
        scen_data = _FP.slice_multinetwork(data; scenario=s, year=y)
        pm = pm_sec[i] = _PM.instantiate_model(scen_data, model_type, sec_bm; ref_extensions, kwargs...)
        add_benders_mp_sp_nw_lookup!(pm, pm_main)
        JuMP.relax_integrality(pm.model)
        JuMP.set_optimizer(pm.model, sec_opt)
        if algo.silent
            JuMP.set_silent(pm.model)
        end
    end

    Memento.debug(_LOGGER, "Main model has $(JuMP.num_variables(pm_main.model)) variables and $(sum([JuMP.num_constraints(pm_main.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_main.model)])) constraints initially.")
    Memento.debug(_LOGGER, "The first secondary model has $(JuMP.num_variables(first(pm_sec).model)) variables and $(sum([JuMP.num_constraints(first(pm_sec).model, f, s) for (f,s) in JuMP.list_of_constraint_types(first(pm_sec).model)])) constraints initially.")

    return pm_main, pm_sec, num_sp, sp_obj_lb_var
end


function add_benders_mp_sp_nw_lookup!(one_pm_sec, pm_main)
    mp_sp_nw_lookup = one_pm_sec.ref[:slice]["benders_mp_sp_nw_lookup"] = Dict{Int,Int}()
    slice_orig_nw_lookup = one_pm_sec.ref[:slice]["slice_orig_nw_lookup"]
    for n in _FP.nw_ids(one_pm_sec; hour=1)
        orig_n = slice_orig_nw_lookup[n]
        int_var_n = _FP.first_id(pm_main, orig_n, :scenario)
        mp_sp_nw_lookup[int_var_n] = n
    end
end

function fix_and_optimize_secondary!(pm_sec, main_var_values)
    Threads.@threads for pm in pm_sec
        fix_sec_var_values!(pm, main_var_values)
        JuMP.optimize!(pm.model)
        check_solution_secondary(pm)
    end
end

function check_solution_main(pm)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Main problem: $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
end

function check_solution_secondary(pm)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Secondary problem, scenario $(_FP.dim_meta(pm,:scenario,"orig_id")), year $(_FP.dim_meta(pm,:year,"orig_id")): $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
end

function get_var_values(pm)
    values = Dict{Int,Any}()
    for n in _FP.nw_ids(pm, hour=1, scenario=1)
        values_n = values[n] = Dict{Symbol,Any}()
        for (key, var_array) in _PM.var(pm, n)
            # idx is a JuMP.Containers.DenseAxisArrayKey{Tuple{Int64}}. idx[1] is an Int
            values_n[key] = Dict{Int,Int}((idx[1],round(Int,JuMP.value(var_array[idx]))) for idx in keys(var_array))
        end
    end
    return values
end

function fix_main_var_values!(pm, main_var_values)
    for (n, key_var) in main_var_values
        for (key, var) in key_var
            for (idx, value) in var
                z_main = _PM.var(pm, n, key, idx)
                JuMP.fix(z_main, value; force=true)
            end
        end
    end
end

function fix_sec_var_values!(pm, main_var_values)
    for (main_nw_id, sec_nw_id) in pm.ref[:slice]["benders_mp_sp_nw_lookup"]
        for (key, var) in main_var_values[main_nw_id]
            if haskey(_PM.var(pm, sec_nw_id), key)
                for (idx, value) in var
                    z_sec = _PM.var(pm, sec_nw_id, key, idx)
                    JuMP.fix(z_sec, value; force=true)
                end
            end
        end
    end
end

function record_statistics!(stat, algo, iter, iter_cuts, inv_cost, op_cost, sol_value, ub, lb, rel_gap, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)
    value = Dict{String,Any}()
    value["inv_cost"] = inv_cost
    value["op_cost"] = op_cost
    value["sol_value"] = sol_value
    value["ub"] = ub
    value["lb"] = lb
    value["rel_gap"] = rel_gap
    value["current_best"] = current_best

    main = Dict{String,Any}()
    main["sol"] = main_var_values
    main["iter_cuts"] = iter_cuts
    main["nvar"] = JuMP.num_variables(pm_main.model)
    main["ncon"] = sum([JuMP.num_constraints(pm_main.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_main.model)])

    secondary = Dict{String,Any}()
    secondary["nvar"] = JuMP.num_variables(first(pm_sec).model)
    secondary["ncon"] = sum([JuMP.num_constraints(first(pm_sec).model, f, s) for (f,s) in JuMP.list_of_constraint_types(first(pm_sec).model)])

    time = Dict{String,Any}()
    time["iteration"] = time_iteration
    time["main"] = time_main
    time["secondary"] = time_sec
    time["other"] = time_iteration - (time_main + time_sec)

    stat[iter] = Dict{String,Any}("iter" => iter, "value" => value, "main" => main, "secondary" => secondary, "time" => time)

    log_statistics(algo, stat[iter])
end

function calc_optimality_cut(pm_main, one_pm_sec, main_var_values)
    scen_id = _FP.dim_meta(one_pm_sec, :scenario, "orig_id")
    year_id = _FP.dim_meta(one_pm_sec, :year, "orig_id")
    optimality_cut_expr = JuMP.AffExpr(JuMP.objective_value(one_pm_sec.model))
    for (main_nw_id, sec_nw_id) in one_pm_sec.ref[:slice]["benders_mp_sp_nw_lookup"]
        for (key, var) in main_var_values[main_nw_id]
            if haskey(_PM.var(one_pm_sec, sec_nw_id), key)
                for (idx, value) in var
                    z_main = _PM.var(pm_main, main_nw_id, key, idx)
                    z_sec = _PM.var(one_pm_sec, sec_nw_id, key, idx)
                    lam = JuMP.reduced_cost(z_sec)
                    JuMP.add_to_expression!(optimality_cut_expr, lam*(z_main-value))
                    Memento.trace(_LOGGER, @sprintf("Optimality cut term for (scenario%4i, year%2i): %15.1f * (%18s - %3.1f)", scen_id, year_id, lam, z_main, value))
                end
            end
        end
    end
    return optimality_cut_expr
end

function build_solution(pm_main, pm_sec, solution_processors)
    solution_main = _IM.build_solution(pm_main)
    num_sp = length(pm_sec)
    sol = Vector{Dict{String,Any}}(undef, num_sp)
    Threads.@threads for p in 1:num_sp
        sol[p] = _IM.build_solution(pm_sec[p]; post_processors=solution_processors)
        lookup = pm_sec[p].ref[:slice]["slice_orig_nw_lookup"]
        nw_orig = Dict{String,Any}("$(lookup[parse(Int,n_slice)])"=>nw for (n_slice,nw) in sol[p]["nw"])
        sol[p]["nw"] = nw_orig
    end
    solution_sec = Dict{String,Any}(k=>v for (k,v) in sol[1] if k != "nw")
    solution_sec["nw"] = merge([s["nw"] for s in sol]...)
    combine_sol_dict!(solution_sec, solution_main) # It is good that `solution_sec` is the first because 1) it has most of the data and 2) its integer values are rounded.
end

function build_result(ub, lb, solution, termination_status, stat, time_procedure_start, time_build)
    result = Dict{String,Any}()
    result["objective"] = ub
    result["objective_lb"] = lb
    result["solution"] = solution
    result["termination_status"] = termination_status
    result["stat"] = stat
    time_proc = Dict{String,Any}()
    time_proc["total"] = time() - time_procedure_start # Time spent after this line is not measured
    time_proc["build"] = time_build
    time_proc["main"] = sum(s["time"]["main"] for s in values(stat))
    time_proc["secondary"] = sum(s["time"]["secondary"] for s in values(stat))
    time_proc["other"] = time_proc["total"] - (time_proc["build"] + time_proc["main"] + time_proc["secondary"])
    result["time"] = time_proc

    Memento.debug(_LOGGER, @sprintf("Benders decomposition time: %.1f s (%.0f%% building models, %.0f%% main prob, %.0f%% secondary probs, %.0f%% other)",
        time_proc["total"],
        100 * time_proc["build"] / time_proc["total"],
        100 * time_proc["main"] / time_proc["total"],
        100 * time_proc["secondary"] / time_proc["total"],
        100 * time_proc["other"] / time_proc["total"]
    ))
    return result
end
