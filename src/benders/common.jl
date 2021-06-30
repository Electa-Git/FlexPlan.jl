"""
Abstract type for Benders decomposition algorithms.

All concrete types shall have the following fields:
- `rtol`: stop when `(ub-lb)/abs(ub) < obj_rtol`, where `ub` and `lb` are the upper and lower bounds of the optimal solution value. Default: `sqrt(eps())`.
- `max_iter`: maximum number of iterations before stopping. Default: 1000.
- `silent`: require the solvers to produce no output; take precedence over any other attribute controlling verbosity. Default: `true`.
"""
abstract type BendersAlgorithm end

"A macro for adding the standard fields to a concrete BendersAlgorithm type"
_IM.@def benders_fields begin
    rtol::Float64
    max_iter::Int
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


## Common auxiliary functions

function check_solution_main(pm, iter)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Iteration $iter, main problem: $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
end

function check_solution_secondary(pm, iter)
    if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Iteration $iter, secondary problem, scenario $(first(keys(pm.ref[:scenario]))): $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
    end
end

function get_var_values(pm)
    values = Dict{Int,Any}()
    for (n,nw) in _PM.nws(pm)
        if n == nw[:benders]["first_nw"] # TODO: improve by looping over an adequate data structure instead of checking equality for each nw
            values_n = values[n] = Dict{Symbol,Any}()
            for (key, var_array) in _PM.var(pm, n)
                # idx is a JuMP.Containers.DenseAxisArrayKey{Tuple{Int64}}. idx[1] is an Int
                values_n[key] = Dict{Int,Int}((idx[1],round(Int,JuMP.value(var_array[idx]))) for idx in keys(var_array))
            end
        end
    end
    return values
end

function fix_var_values!(pm, values)
    lookup = pm.ref[:benders]["scenario_sub_nw_lookup"]
    for (n, key_vars) in values
        for (key, var) in key_vars
            for (idx, value) in var
                z_sec = _PM.var(pm, lookup[n], key, idx)
                JuMP.fix(z_sec, value; force=true)
            end
        end
    end
end

function add_optimality_cuts!(pm_main, pm_sec, main_var_values, epi)
    for (s, pm) in enumerate(pm_sec)
        lookup = pm.ref[:benders]["scenario_sub_nw_lookup"]
        optimality_cut = JuMP.AffExpr(JuMP.objective_value(pm.model))
        for (n, key_vars) in main_var_values
            for (key, var) in key_vars
                for (idx, value) in var
                    z_main = _PM.var(pm_main, n, key, idx)
                    z_sec = _PM.var(pm, lookup[n], key, idx)
                    lam = JuMP.reduced_cost(z_sec)
                    JuMP.add_to_expression!(optimality_cut, lam*(z_main-value))
                    Memento.trace(_LOGGER, @sprintf("Optimality cut term for nw = %4i: %15.1f * (%18s - %3.1f)", lookup[n], lam, z_main, value))
                end
            end
        end
        JuMP.@constraint(pm_main.model, epi[s] >= optimality_cut)
    end
end

function calc_first_iter_result(pm_sec, inv_cost_expr)
    sp_obj = sum(pm.ref[:scenario_prob]["$s"] * JuMP.objective_value(pm.model) for (s, pm) in enumerate(pm_sec))
    inv_cost = JuMP.value(inv_cost_expr)
    op_cost = sp_obj
    sol_value = inv_cost + op_cost
    lb = -Inf
    return inv_cost, op_cost, sol_value, lb
end

function calc_iter_result(pm_main, pm_sec, epi)
    mp_obj = JuMP.objective_value(pm_main.model)
    sp_obj = sum(pm.ref[:scenario_prob]["$s"] * JuMP.objective_value(pm.model) for (s, pm) in enumerate(pm_sec))
    epi_value = sum(pm.ref[:scenario_prob]["$s"] * JuMP.value(epi[s]) for (s, pm) in enumerate(pm_sec))
    inv_cost = mp_obj - epi_value
    op_cost = sp_obj
    sol_value = mp_obj - epi_value + sp_obj
    lb = mp_obj
    return inv_cost, op_cost, sol_value, lb
end

function log_statistics!(stat, i, inv_cost, op_cost, sol_value, ub, lb, rel_gap, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)
    if current_best
        Memento.info(_LOGGER, @sprintf("┃ •%4i │%11.3e%12.3e%12.3e │%11.3e%12.3e%12.3e ┃", i, inv_cost, op_cost, sol_value, ub, lb, rel_gap))
    else
        Memento.info(_LOGGER, @sprintf("┃  %4i │%11.3e%12.3e%12.3e │%11.3e%12.3e%12.3e ┃", i, inv_cost, op_cost, sol_value, ub, lb, rel_gap))
    end

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

    stat[i] = Dict{String,Any}("value" => value, "main" => main, "secondary" => secondary, "time" => time)
end

function add_benders_nw_data!(data::Dict{String,Any})
    if _IM.ismultinetwork(data)
        if haskey(data, "sub_nw")
            for sub in values(data["sub_nw"])
                benders_data = Dict{String,Any}("first_nw" => minimum(sub))
                for n in sub
                    data["nw"][n]["benders"] = benders_data # All nws in the same sub_nw refer to the same Dict
                end
            end
        else
            benders_data = Dict{String,Any}("first_nw" => minimum(parse.(Int,keys(data["nw"]))))
            for nw in values(data["nw"])
                nw["benders"] = benders_data # All nws refer to the same Dict
            end
        end
    else
        data["benders"] = Dict{String,Any}("first_nw" => 0)
    end
end

function add_benders_data!(data::Dict{String,Any})
    lookup = Dict{Int,Int}()
    if _IM.ismultinetwork(data)
        if haskey(data, "sub_nw")
            # TODO: implement this case
            @assert false "Not yet implemented"
            #for sub in values(data["sub_nw"])
            #    ...
            #end
        else
            lookup[1] = minimum(parse.(Int,keys(data["nw"])))
        end
    else
        # TODO: implement this case
        @assert false "Not yet implemented"
    end
    data["benders"] = Dict{String,Any}("scenario_sub_nw_lookup" => lookup)
end
