# Modern implementation of Benders decomposition

"""
    Modern <: BendersAlgorithm

Parameters for modern implementation of Benders decomposition:
- `max_iter`: maximum number of iterations before stopping. Default: 1000.
- `tightening_rtol`: add an optimality cut only if `(sp_obj-sp_obj_lb)/abs(sp_obj) > tightening_rtol`, where `sp_obj` is the objective function value of the secondary problem and and `sp_obj_lb` is the value of the corresponding surrogate function. Default: `sqrt(eps())`.
- `sp_obj_lb_min`: constant term of the initial optimality cut, which prevents the main problem from being unbounded at the beginning. Default: `-1e12`."
- `silent`: require the solvers to produce no output; take precedence over any other attribute controlling verbosity. Default: `true`.
"""
struct Modern <: BendersAlgorithm
    @benders_fields
end

function Modern(;
        max_iter = 1000,
        tightening_rtol = sqrt(eps()),
        sp_obj_lb_min = -1e12,
        silent = true
    )
    Modern(
        max_iter,
        tightening_rtol,
        sp_obj_lb_min,
        silent
    )
end

"""
    run_benders_decomposition(algo::Modern, <arguments>, <keyword arguments>)

Run the modern implementation of Benders decomposition, where the main problem is solved once.
The modern implementation uses callbacks (lazy constraints) to solve secondary problems
whenever an optimal integer solution of the main problem is found.
"""
function run_benders_decomposition(
        algo::Modern,
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

    ########################################################################################

    function optimality_cut_callback(cb_data)
        iter += 1
        if iter > algo.max_iter
            if iter == algo.max_iter + 1
                Memento.info(_LOGGER, "┠─────────────┴────────────────────────────────────┴────────────┨")
                Memento.info(_LOGGER, "┃   ▴            Stopping: iteration limit reached              ┃")
                Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            end
            return
        end
        status = JuMP.callback_node_status(cb_data, pm_main.model)
        if status != _MOI.CALLBACK_NODE_STATUS_INTEGER
            if status == _MOI.CALLBACK_NODE_STATUS_FRACTIONAL
                Memento.warn(_LOGGER, "Benders callback called on fractional solution. Ignoring.")
                return
            else
                @assert status == _MOI.CALLBACK_NODE_STATUS_UNKNOWN
                Memento.error(_LOGGER, "Benders callback called on unknown solution status (might be fractional or integer).")
            end
        end
        main_var_values = get_var_values(algo, pm_main, cb_data)
        time_main = time() - time_main_start

        time_sec_start = time()
        Threads.@threads for pm in pm_sec
            fix_var_values!(pm, main_var_values)
            JuMP.optimize!(pm.model)
            check_solution_secondary(pm, iter)
        end
        time_sec = time() - time_sec_start

        if iter == 1
            if !JuMP.has_duals(first(pm_sec).model) # If this check passes here, no need to check again in subsequent iterations.
                Memento.error(_LOGGER, "Solver $(JuMP.solver_name(first(pm_sec).model)) is unable to provide dual values.")
            end
            Memento.info(_LOGGER, "┏━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━┓")
            Memento.info(_LOGGER, "┃ iter.  cuts │  inv. cost  oper. cost    solution │         UB ┃")
            Memento.info(_LOGGER, "┠─────────────┼────────────────────────────────────┼────────────┨")
        end

        inv_cost, op_cost, sol_value, rel_tightening = calc_iter_result(algo, cb_data, mp_obj_expr, pm_sec, sp_obj_lb_var, sp_weights)
        if sol_value < ub
            ub = sol_value
            current_best = true
            best_main_var_values = main_var_values
        else
            current_best = false
        end
        iter_cuts = 0
        for s in 1:num_scenarios
            if rel_tightening[s] > algo.tightening_rtol
                iter_cuts += 1
                optimality_cut_expr = calc_optimality_cut(pm_main, pm_sec[s], main_var_values)
                cut = JuMP.@build_constraint(sp_obj_lb_var[s] >= optimality_cut_expr)
                _MOI.submit(pm_main.model, _MOI.LazyConstraint(cb_data), cut)
            end
        end
        time_iteration = time() - time_iteration_start # Time spent after this line is not measured
        record_statistics!(stat, algo, iter, iter_cuts, inv_cost, op_cost, sol_value, ub, NaN, NaN, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)
        time_iteration_start = time_main_start = time()
    end

    ########################################################################################

    time_procedure_start = time()
    Memento.debug(_LOGGER, "Modern Benders decomposition started. Available threads: $(Threads.nthreads()).")
    if !haskey(data, "scenario")
        Memento.error(_LOGGER, "Missing \"scenario\" key in data.")
    end
    num_scenarios = length(data["scenario"])
    add_benders_nw_data!(data)
    ub = Inf
    lb = -Inf
    iter = 0
    current_best = true
    best_main_var_values = nothing
    stat = Dict{Int,Any}()

    pm_main = _PM.instantiate_model(data, model_type, main_bm; ref_extensions, kwargs...)
    JuMP.set_optimizer(pm_main.model, main_opt)
    if algo.silent
        JuMP.set_silent(pm_main.model)
    end
    sp_weights = [data["scenario_prob"]["$s"] for s in 1:num_scenarios]
    sp_obj_lb_var = JuMP.@variable(pm_main.model, [s=1:num_scenarios], lower_bound=algo.sp_obj_lb_min)
    JuMP.@objective(pm_main.model, Min, JuMP.objective_function(pm_main.model) + sum(prob * sp_obj_lb_var[s] for (s, prob) in enumerate(sp_weights)))
    mp_obj_expr = JuMP.objective_function(pm_main.model)
    _MOI.set(pm_main.model, _MOI.LazyConstraintCallback(), optimality_cut_callback)

    pm_sec = Vector{model_type}(undef, num_scenarios)
    Threads.@threads for s in 1:num_scenarios
        ss = "$s"
        scen = data["scenario"][ss]
        scen_data = copy(data)
        scen_data["scenario"] = Dict{String,Any}(ss => scen)
        scen_data["scenario_prob"] = Dict{String,Any}(ss => sp_weights[s])
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

    Memento.debug(_LOGGER, "Main model has $(JuMP.num_variables(pm_main.model)) variables and $(sum([JuMP.num_constraints(pm_main.model, f, s) for (f,s) in JuMP.list_of_constraint_types(pm_main.model)])) constraints initially.")
    Memento.debug(_LOGGER, "Each secondary model has $(JuMP.num_variables(first(pm_sec).model)) variables and $(sum([JuMP.num_constraints(first(pm_sec).model, f, s) for (f,s) in JuMP.list_of_constraint_types(first(pm_sec).model)])) constraints initially.")

    time_build = time() - time_procedure_start

    time_iteration_start = time_main_start = time()
    JuMP.optimize!(pm_main.model)
    check_solution_main(pm_main, iter)
    if iter <= algo.max_iter
        Memento.info(_LOGGER, "┠─────────────┴────────────────────────────────────┴────────────┨")
        Memento.info(_LOGGER, "┃               Stopping: optimal within tolerance              ┃")
        Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    end

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

function get_var_values(algo::Modern, pm, cb_data)
    values = Dict{Int,Any}()
    for (n,nw) in _PM.nws(pm)
        if n == nw[:benders]["first_nw"] # TODO: improve by looping over an adequate data structure instead of checking equality for each nw
            values_n = values[n] = Dict{Symbol,Any}()
            for (key, var_array) in _PM.var(pm, n)
                # idx is a JuMP.Containers.DenseAxisArrayKey{Tuple{Int64}}. idx[1] is an Int
                values_n[key] = Dict{Int,Int}((idx[1],round(Int,JuMP.callback_value(cb_data, var_array[idx]))) for idx in keys(var_array))
            end
        end
    end
    return values
end

function calc_iter_result(algo::Modern, cb_data, mp_obj_expr, pm_sec, sp_obj_lb_var, sp_weights)
    mp_obj = JuMP.callback_value(cb_data, mp_obj_expr)
    sp_obj = [JuMP.objective_value(pm.model) for pm in pm_sec]
    sp_obj_lb = [JuMP.callback_value(cb_data, lb) for lb in sp_obj_lb_var]
    rel_tightening = (sp_obj .- sp_obj_lb) ./ abs.(sp_obj)
    inv_cost = mp_obj - sum(sp_weights .* sp_obj_lb)
    op_cost = sum(sp_weights .* sp_obj)
    sol_value = inv_cost + op_cost
    return inv_cost, op_cost, sol_value, rel_tightening
end

function log_statistics(algo::Modern, st)
    iter = st["iter"]
    cuts = st["main"]["iter_cuts"]
    st = st["value"]
    Memento.info(_LOGGER, @sprintf("┃ %s%4i%6i │%11.3e%12.3e%12.3e │%11.3e ┃", st["current_best"] ? '•' : ' ', iter, cuts, st["inv_cost"], st["op_cost"], st["sol_value"], st["ub"]))
end
