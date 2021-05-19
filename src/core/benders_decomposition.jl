export run_benders_decomposition

"""
    run_benders_decomposition(data, model_t, main_opt, sec_opt, main_bm, sec_bm, <keyword arguments>)

Run Benders' procedure on `data` using the network model type `model_t`.

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
- `rtol = sqrt(eps())`: stops when `(ub-lb)/abs(ub) < rtol`, where `ub` and `lb` are the
  upper and lower bounds of the optimal solution value.
- `max_iter = 1000`: maximum number of iterations before stopping.
- `silent = true`: requires the solvers to produce no output; takes precedence over any
  other attribute controlling verbosity.
- `kwargs...`: passed to `PowerModels.instantiate_model()` when building main and secondary
  problems.

# Implementation
The objective function in `main_bm` must contain only the investment-related terms
(auxiliary variables for Benders' optimality cuts are added later).
"""
function run_benders_decomposition(
        data::Dict{String,<:Any},
        model_t::Type,
        main_opt::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        sec_opt::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        main_bm::Function,
        sec_bm::Function;
        ref_extensions::Vector{<:Function} = Function[],
        solution_processors::Vector{<:Function} = Function[],
        rtol = sqrt(eps()),
        max_iter = 1000,
        silent = true,
        kwargs...
    )

    time_procedure_start = time()
    Memento.debug(_LOGGER, "Benders' decomposition started")

    add_benders_data!(data)

    pm_main = _PM.instantiate_model(data, model_t, main_bm; ref_extensions, kwargs...)
    investment_cost_expr = JuMP.objective_function(pm_main.model)
    JuMP.set_optimizer(pm_main.model, main_opt)
    if silent
        JuMP.set_silent(pm_main.model)
    end

    pm_sec = _PM.instantiate_model(data, model_t, sec_bm; ref_extensions, kwargs...)
    JuMP.relax_integrality(pm_sec.model)
    JuMP.set_optimizer(pm_sec.model, sec_opt)
    if silent
        JuMP.set_silent(pm_sec.model)
    end

    time_build = time() - time_procedure_start

    stat = Dict{Int,Any}()

    ## First iteration

    time_iteration_start = time()
    i = 1

    time_main_start = time()
    optimize_and_check!(pm_main.model, "main", i)
    main_var_values = get_var_values(pm_main)
    time_main = time() - time_main_start
    Memento.debug(_LOGGER, "Main model has $(JuMP.num_variables(pm_main.model)) variables and $(sum([JuMP.num_constraints(pm_main.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_main.model)])) constraints initially.")

    time_sec_start = time()
    fix_var_values!(pm_sec, main_var_values)
    optimize_and_check!(pm_sec.model, "secondary", i)
    time_sec = time() - time_sec_start
    if !JuMP.has_duals(pm_sec.model) # If this check passes here, no need to check again in subsequent iterations.
        Memento.error(_LOGGER, "Solver $(JuMP.solver_name(pm_sec.model)) is unable to provide dual values.")
    end
    Memento.debug(_LOGGER, "Secondary model has $(JuMP.num_variables(pm_sec.model)) variables and $(sum([JuMP.num_constraints(pm_sec.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_sec.model)])) constraints initially.")

    Memento.info(_LOGGER, "┏━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    Memento.info(_LOGGER, "┃ iter. │  inv. cost  oper. cost    solution │         UB          LB    rel. gap ┃")
    Memento.info(_LOGGER, "┠───────┼────────────────────────────────────┼────────────────────────────────────┨")

    inv_cost, op_cost, sol_value, lb = calc_first_iter_result(pm_main, pm_sec, investment_cost_expr)
    ub = sol_value
    solution = _IM.build_solution(pm_sec; post_processors=solution_processors)
    time_iteration = time() - time_iteration_start # Time spent after this line is not measured
    log_statistics!(stat, i, inv_cost, op_cost, sol_value, ub, lb, Inf, true, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)

    epi = JuMP.@variable(pm_main.model, base_name="benders_epigraph")
    JuMP.@objective(pm_main.model, Min, investment_cost_expr + epi)

    ## Subsequent iterations

    while true
        time_iteration_start = time()
        if i == max_iter # Do not move to the end of the iteration, otherwise it does not stop the procedure when max_iter == 1
            Memento.info(_LOGGER, "┠───────┴────────────────────────────────────┴────────────────────────────────────┨")
            Memento.info(_LOGGER, "┃   ▴                    Stopping: iteration limit reached                        ┃")
            Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            break
        end
        i += 1
        current_best = false

        time_main_start = time()
        add_optimality_cut!(pm_main, pm_sec, main_var_values, epi)
        optimize_and_check!(pm_main.model, "main", i)
        main_var_values = get_var_values(pm_main)
        time_main = time() - time_main_start

        time_sec_start = time()
        fix_var_values!(pm_sec, main_var_values)
        optimize_and_check!(pm_sec.model, "secondary", i)
        time_sec = time() - time_sec_start

        inv_cost, op_cost, sol_value, lb = calc_iter_result(pm_main, pm_sec, epi)

        if sol_value < ub
            ub = sol_value
            current_best = true
            solution = _IM.build_solution(pm_sec; post_processors=solution_processors)
        end
        rel_gap = (ub-lb)/abs(ub)
        time_iteration = time() - time_iteration_start # Time spent after this line is not measured
        log_statistics!(stat, i, inv_cost, op_cost, sol_value, ub, lb, rel_gap, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)

        if rel_gap ≤ rtol
            Memento.info(_LOGGER, "┠───────┴────────────────────────────────────┴────────────────────────────────────┨")
            Memento.info(_LOGGER, "┃                       Stopping: optimal within tolerance                  ▴     ┃")
            Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            break
        end
    end

    # TODO: possible common parts between first and subsequent iterations could be grouped in a dedicated function.

    result = Dict{String,Any}()
    result["objective"]    = ub
    result["objective_lb"] = lb
    result["solution"]     = solution
    result["stat"]         = stat
    result["solve_time"]   = time() - time_procedure_start # Time spent after this line is not measured
    time_proc = Dict{String,Any}()
    time_proc["total"] = result["solve_time"]
    time_proc["build"] = time_build
    time_proc["main"] = sum(s["time"]["main"] for s in values(stat))
    time_proc["secondary"] = sum(s["time"]["secondary"] for s in values(stat))
    time_proc["other"] = time_proc["total"] - (time_proc["build"] + time_proc["main"] + time_proc["secondary"])
    result["time"] = time_proc

    Memento.debug(_LOGGER, @sprintf("Benders' decomposition time: %.1f s (%.0f%% building models, %.0f%% main prob, %.0f%% secondary probs, %.0f%% other)",
        time_proc["total"],
        100 * time_proc["build"] / time_proc["total"],
        100 * time_proc["main"] / time_proc["total"],
        100 * time_proc["secondary"] / time_proc["total"],
        100 * time_proc["other"] / time_proc["total"]
    ))
    return result
end

function optimize_and_check!(model, model_name, iter)
    JuMP.optimize!(model)
    if JuMP.termination_status(model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "At iteration $iter, $(JuMP.solver_name(model)) termination status on $model_name problem is: $(JuMP.termination_status(model)).")
    end
end

function get_var_values(pm)
    values = Dict{Int,Any}()
    for (n,nw) in _PM.nws(pm)
        if n == nw[:benders]["first_nw"]
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
    for (n, key_vars) in values
        for (key, var) in key_vars
            for (idx, value) in var
                z_sec = _PM.var(pm, n, key, idx)
                JuMP.fix(z_sec, value; force=true)
            end
        end
    end
end

function add_optimality_cut!(pm_main, pm_sec, main_var_values, epi)
    optimality_cut = JuMP.AffExpr(JuMP.objective_value(pm_sec.model))
    for (n, key_vars) in main_var_values
        for (key, var) in key_vars
            for (idx, value) in var
                z_main = _PM.var(pm_main, n, key, idx)
                z_sec = _PM.var(pm_sec, n, key, idx)
                lam = JuMP.reduced_cost(z_sec)
                JuMP.add_to_expression!(optimality_cut, lam*(z_main-value))
                Memento.trace(_LOGGER, @sprintf("Optimality cut term for nw = %4i: %15.1f * (%18s - %3.1f)", n, lam, z_main, value))
            end
        end
    end
    JuMP.@constraint(pm_main.model, epi ≥ optimality_cut)
end

function calc_first_iter_result(pm_main, pm_sec, inv_cost_expr)
    mp_obj = JuMP.objective_value(pm_main.model)
    sp_obj = JuMP.objective_value(pm_sec.model)
    inv_cost = JuMP.value(inv_cost_expr)
    op_cost = sp_obj
    sol_value = inv_cost + op_cost
    lb = -Inf
    return inv_cost, op_cost, sol_value, lb
end

function calc_iter_result(pm_main, pm_sec, epi)
    mp_obj = JuMP.objective_value(pm_main.model)
    sp_obj = JuMP.objective_value(pm_sec.model)
    epi_value = JuMP.value(epi)
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
    secondary["nvar"] = JuMP.num_variables(pm_sec.model)
    secondary["ncon"] = sum([JuMP.num_constraints(pm_sec.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_sec.model)])

    time = Dict{String,Any}()
    time["iteration"] = time_iteration
    time["main"] = time_main
    time["secondary"] = time_sec
    time["other"] = time_iteration - (time_main + time_sec)

    stat[i] = Dict{String,Any}("value" => value, "main" => main, "secondary" => secondary, "time" => time)
end

function add_benders_data!(data::Dict{String,Any})
    if _IM.ismultinetwork(data)
        if haskey(data, "sub_nw")
            for sub in values(data["sub_nw"])
                benders_data = Dict{String,Any}("first_nw" => min(sub...))
                for n in sub
                    data["nw"][n]["benders"] = benders_data # All nws in the same sub_nw refer to the same Dict
                end
            end
        else
            benders_data = Dict{String,Any}("first_nw" => min(parse.(Int,keys(data["nw"]))...))
            for nw in values(data["nw"])
                nw["benders"] = benders_data # All nws refer to the same Dict
            end
        end
    else
        data["benders"] = Dict{String,Any}("first_nw" => 0)
    end
end
