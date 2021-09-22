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
  solutions of both main and secondary problems.
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

function add_benders_mp_sp_nw_lookup!(one_pm_sec, pm_main)
    mp_sp_nw_lookup = one_pm_sec.ref[:slice]["benders_mp_sp_nw_lookup"] = Dict{Int,Int}()
    slice_orig_nw_lookup = one_pm_sec.ref[:slice]["slice_orig_nw_lookup"]
    for n in _FP.nw_ids(one_pm_sec; hour=1)
        orig_n = slice_orig_nw_lookup[n]
        int_var_n = _FP.first_id(pm_main, orig_n, :scenario)
        mp_sp_nw_lookup[int_var_n] = n
    end
end

function check_solution_main(pm, iter)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Iteration $iter, main problem: $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
end

function check_solution_secondary(pm, iter)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Iteration $iter, secondary problem, scenario $(_FP.dim_meta(pm,:scenario,"orig_id")), year $(_FP.dim_meta(pm,:year,"orig_id")): $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
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

function build_sec_solution(one_pm_sec, solution_processors)
    sol = _IM.build_solution(one_pm_sec; post_processors=solution_processors)
    lookup = one_pm_sec.ref[:slice]["slice_orig_nw_lookup"]
    nw_orig = Dict{String,Any}("$(lookup[parse(Int,n_slice)])"=>nw for (n_slice,nw) in sol["nw"])
    sol["nw"] = nw_orig
    return sol
end
