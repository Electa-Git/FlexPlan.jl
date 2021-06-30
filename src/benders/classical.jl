# Classical implementation of Benders decomposition

"Parameters for classical implementation of Benders decomposition"
struct Classical <: BendersAlgorithm
    @benders_fields
end

function Classical(;
        rtol = sqrt(eps()),
        max_iter = 1000,
        silent = true
    )
    Classical(
        rtol,
        max_iter,
        silent
    )
end

"""
    run_benders_decomposition(algo::Classical, <arguments>, <keyword arguments>)

Run the classical implementation of Benders decomposition, where the main problem is solved once per iteration.
"""
function run_benders_decomposition(
        algo::Classical,
        data::Dict{String,<:Any},
        model_type::Type,
        main_opt::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        sec_opt::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        main_bm::Function,
        sec_bm::Function;
        ref_extensions::Vector{<:Function} = Function[],
        solution_processors::Vector{<:Function} = Function[],
        kwargs...
    )

    time_procedure_start = time()
    Memento.debug(_LOGGER, "Classical Benders decomposition started. Available threads: $(Threads.nthreads()).")

    if !haskey(data, "scenario")
        Memento.error(_LOGGER, "Missing \"scenario\" key in data.")
    end
    num_scenarios = length(data["scenario"])
    add_benders_nw_data!(data)

    pm_main = _PM.instantiate_model(data, model_type, main_bm; ref_extensions, kwargs...)
    investment_cost_expr = JuMP.objective_function(pm_main.model)
    JuMP.set_optimizer(pm_main.model, main_opt)
    if algo.silent
        JuMP.set_silent(pm_main.model)
    end

    pm_sec = Vector{model_type}(undef, num_scenarios)
    Threads.@threads for s in 1:num_scenarios
        ss = "$s"
        scen = data["scenario"][ss]
        scen_data = copy(data)
        scen_data["scenario"] = Dict{String,Any}(ss => scen)
        scen_data["scenario_prob"] = Dict{String,Any}(ss => data["scenario_prob"][ss])
        scen_data["nw"] = Dict{String,Any}("$n" => data["nw"]["$n"] for n in values(scen))
        add_benders_nw_data!(scen_data)
        add_benders_data!(scen_data)
        pm = pm_sec[s] = _PM.instantiate_model(scen_data, model_type, sec_bm; ref_extensions, kwargs...)
        JuMP.relax_integrality(pm.model)
        JuMP.set_optimizer(pm.model, sec_opt)
        if algo.silent
            JuMP.set_silent(pm.model)
        end
    end

    time_build = time() - time_procedure_start

    stat = Dict{Int,Any}()

    ## First iteration

    time_iteration_start = time()
    i = 1

    time_main_start = time()
    JuMP.optimize!(pm_main.model)
    check_solution_main(pm_main, i)
    best_main_var_values = main_var_values = get_var_values(pm_main)
    time_main = time() - time_main_start
    Memento.debug(_LOGGER, "Main model has $(JuMP.num_variables(pm_main.model)) variables and $(sum([JuMP.num_constraints(pm_main.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_main.model)])) constraints initially.")

    time_sec_start = time()
    Threads.@threads for pm in pm_sec
        fix_var_values!(pm, main_var_values)
        JuMP.optimize!(pm.model)
        check_solution_secondary(pm, i)
    end
    time_sec = time() - time_sec_start
    if !JuMP.has_duals(first(pm_sec).model) # If this check passes here, no need to check again in subsequent iterations.
        Memento.error(_LOGGER, "Solver $(JuMP.solver_name(first(pm_sec).model)) is unable to provide dual values.")
    end
    Memento.debug(_LOGGER, "Secondary model has $(JuMP.num_variables(first(pm_sec).model)) variables and $(sum([JuMP.num_constraints(first(pm_sec).model, f, s) for (f,s) in JuMP.list_of_constraint_types(first(pm_sec).model)])) constraints initially.")

    Memento.info(_LOGGER, "┏━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
    Memento.info(_LOGGER, "┃ iter. │  inv. cost  oper. cost    solution │         UB          LB    rel. gap ┃")
    Memento.info(_LOGGER, "┠───────┼────────────────────────────────────┼────────────────────────────────────┨")

    inv_cost, op_cost, sol_value, lb = calc_first_iter_result(pm_sec, investment_cost_expr)
    ub = sol_value
    time_iteration = time() - time_iteration_start # Time spent after this line is not measured
    current_best = true
    log_statistics!(stat, i, inv_cost, op_cost, sol_value, ub, lb, Inf, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)

    epi = JuMP.@variable(pm_main.model, [s=1:num_scenarios], base_name="benders_epigraph")
    JuMP.@objective(pm_main.model, Min, investment_cost_expr + sum(pm.ref[:scenario_prob]["$s"] * epi[s] for (s, pm) in enumerate(pm_sec)))

    ## Subsequent iterations

    while true
        time_iteration_start = time()
        if i == algo.max_iter # Do not move to the end of the iteration, otherwise it does not stop the procedure when max_iter == 1
            Memento.info(_LOGGER, "┠───────┴────────────────────────────────────┴────────────────────────────────────┨")
            Memento.info(_LOGGER, "┃   ▴                    Stopping: iteration limit reached                        ┃")
            Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            break
        end
        i += 1
        current_best = false

        time_main_start = time()
        add_optimality_cuts!(pm_main, pm_sec, main_var_values, epi)
        JuMP.optimize!(pm_main.model)
        check_solution_main(pm_main, i)
        main_var_values = get_var_values(pm_main)
        time_main = time() - time_main_start

        time_sec_start = time()
        Threads.@threads for pm in pm_sec
            fix_var_values!(pm, main_var_values)
            JuMP.optimize!(pm.model)
            check_solution_secondary(pm, i)
        end
        time_sec = time() - time_sec_start

        inv_cost, op_cost, sol_value, lb = calc_iter_result(pm_main, pm_sec, epi)

        if sol_value < ub
            ub = sol_value
            current_best = true
            best_main_var_values = main_var_values
        end
        rel_gap = (ub-lb)/abs(ub)
        time_iteration = time() - time_iteration_start # Time spent after this line is not measured
        log_statistics!(stat, i, inv_cost, op_cost, sol_value, ub, lb, rel_gap, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)

        if rel_gap <= algo.rtol
            Memento.info(_LOGGER, "┠───────┴────────────────────────────────────┴────────────────────────────────────┨")
            Memento.info(_LOGGER, "┃                       Stopping: optimal within tolerance                  ▴     ┃")
            Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            break
        end
    end

    # TODO: possible common parts between first and subsequent iterations could be grouped in a dedicated function.

    sol = Vector{Dict{String,Any}}(undef, num_scenarios)
    if current_best
        Threads.@threads for s in 1:num_scenarios
            sol[s] = _IM.build_solution(pm_sec[s]; post_processors=solution_processors)
        end
    else
        Threads.@threads for s in 1:num_scenarios
            pm = pm_sec[s]
            fix_var_values!(pm, best_main_var_values)
            JuMP.optimize!(pm.model)
            if JuMP.termination_status(pm.model) ∉ (_MOI.OPTIMAL, _MOI.LOCALLY_SOLVED)
                Memento.error(_LOGGER, "Secondary problem, scenario $(first(keys(pm.ref[:scenario]))): $(JuMP.solver_name(pm.model)) termination status is $(JuMP.termination_status(pm.model)).")
            end
            sol[s] = _IM.build_solution(pm; post_processors=solution_processors)
        end
    end
    (solution, sol_rest) = Iterators.peel(sol)
    for sol in sol_rest
        for nw in sol["nw"]
            push!(solution["nw"], nw)
        end
    end

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

    Memento.debug(_LOGGER, @sprintf("Benders decomposition time: %.1f s (%.0f%% building models, %.0f%% main prob, %.0f%% secondary probs, %.0f%% other)",
        time_proc["total"],
        100 * time_proc["build"] / time_proc["total"],
        100 * time_proc["main"] / time_proc["total"],
        100 * time_proc["secondary"] / time_proc["total"],
        100 * time_proc["other"] / time_proc["total"]
    ))
    return result
end
