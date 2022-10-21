# Modern implementation of Benders decomposition

"""
    Modern <: BendersAlgorithm

Parameters for modern implementation of Benders decomposition:
- `max_iter`: maximum number of iterations before stopping. Default: 1000.
- `tightening_rtol`: add an optimality cut only if
  `(sp_obj-sp_obj_lb)/abs(sp_obj) > tightening_rtol`, where `sp_obj` is the objective
  function value of the secondary problem and and `sp_obj_lb` is the value of the
  corresponding surrogate function. Default: `sqrt(eps())`.
- `sp_obj_lb_min`: constant term of the initial optimality cut, which prevents the main
  problem from being unbounded at the beginning. Default: `-1e12`."
- `silent`: require the solvers to produce no output; take precedence over any other
  attribute controlling verbosity. Default: `true`.

!!! info

    The tolerance for stopping the procedure cannot be set here: it will coincide with the
    stopping tolerance attribute(s) of the main problem optimizer.
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
        fix_and_optimize_secondary!(pm_sec, main_var_values)
        time_sec = time() - time_sec_start

        if iter == 1
            if !JuMP.has_duals(first(pm_sec).model) # If this check passes here, no need to check again in subsequent iterations.
                Memento.error(_LOGGER, "Solver $(JuMP.solver_name(first(pm_sec).model)) is unable to provide dual values.")
            end
            Memento.info(_LOGGER, "┏━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━┓")
            Memento.info(_LOGGER, "┃ iter.  cuts │  inv. cost  oper. cost    solution │         UB ┃")
            Memento.info(_LOGGER, "┠─────────────┼────────────────────────────────────┼────────────┨")
        end

        inv_cost, op_cost, sol_value, rel_tightening = calc_iter_result(algo, cb_data, mp_obj_expr, pm_sec, sp_obj_lb_var)
        if sol_value < ub
            ub = sol_value
            current_best = true
        else
            current_best = false
        end
        iter_cuts = add_optimality_cuts!(pm_main, pm_sec, algo, num_sp, sp_obj_lb_var, main_var_values, rel_tightening; cb_data)
        time_iteration = time() - time_iteration_start # Time spent after this line is not measured
        record_statistics!(stat, algo, iter, iter_cuts, inv_cost, op_cost, sol_value, ub, NaN, NaN, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)
        time_iteration_start = time_main_start = time()
    end

    ########################################################################################

    time_procedure_start = time()
    Memento.debug(_LOGGER, "Modern Benders decomposition started. Available threads: $(Threads.nthreads()).")

    pm_main, pm_sec, num_sp, sp_obj_lb_var = instantiate_model(algo, data, model_type, main_opt, sec_opt, main_bm, sec_bm; ref_extensions, kwargs...)
    mp_obj_expr = JuMP.objective_function(pm_main.model)
    _MOI.set(pm_main.model, _MOI.LazyConstraintCallback(), optimality_cut_callback)

    ub = Inf
    lb = -Inf
    iter = 0
    current_best = true
    stat = Dict{Int,Any}()
    time_build = time() - time_procedure_start

    time_iteration_start = time_main_start = time()
    JuMP.optimize!(pm_main.model) # Also solves secondary problems iteratively using the callback
    check_solution_main(pm_main)
    if iter <= algo.max_iter
        Memento.info(_LOGGER, "┠─────────────┴────────────────────────────────────┴────────────┨")
        Memento.info(_LOGGER, "┃               Stopping: optimal within tolerance              ┃")
        Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
    end
    best_main_var_values = get_var_values(pm_main)

    fix_and_optimize_secondary!(pm_sec, best_main_var_values)
    solution = build_solution(pm_main, pm_sec, solution_processors)
    termination_status = iter > algo.max_iter ? _MOI.ITERATION_LIMIT : _MOI.OPTIMAL
    build_result(ub, lb, solution, termination_status, stat, time_procedure_start, time_build)
end

function get_var_values(algo::Modern, pm, cb_data)
    values = Dict{Int,Any}()
    for n in _FP.nw_ids(pm, hour=1, scenario=1)
        values_n = values[n] = Dict{Symbol,Any}()
        for (key, var_array) in _PM.var(pm, n)
            # idx is a JuMP.Containers.DenseAxisArrayKey{Tuple{Int64}}. idx[1] is an Int
            values_n[key] = Dict{Int,Int}((idx[1],round(Int,JuMP.callback_value(cb_data, var_array[idx]))) for idx in keys(var_array))
        end
    end
    return values
end

function calc_iter_result(algo::Modern, cb_data, mp_obj_expr, pm_sec, sp_obj_lb_var)
    mp_obj = JuMP.callback_value(cb_data, mp_obj_expr)
    sp_obj = [JuMP.objective_value(pm.model) for pm in pm_sec]
    sp_obj_lb = [JuMP.callback_value(cb_data, lb) for lb in sp_obj_lb_var]
    rel_tightening = (sp_obj .- sp_obj_lb) ./ abs.(sp_obj)
    inv_cost = mp_obj - sum(sp_obj_lb)
    op_cost = sum(sp_obj)
    sol_value = inv_cost + op_cost
    return inv_cost, op_cost, sol_value, rel_tightening
end

function add_optimality_cuts!(pm_main, pm_sec, algo::Modern, num_sp, sp_obj_lb_var, main_var_values, rel_tightening; cb_data)
    iter_cuts = 0
    for p in 1:num_sp
        if rel_tightening[p] > algo.tightening_rtol
            iter_cuts += 1
            optimality_cut_expr = calc_optimality_cut(pm_main, pm_sec[p], main_var_values)
            cut = JuMP.@build_constraint(sp_obj_lb_var[p] >= optimality_cut_expr)
            _MOI.submit(pm_main.model, _MOI.LazyConstraint(cb_data), cut)
        end
    end
    return iter_cuts
end

function log_statistics(algo::Modern, st)
    iter = st["iter"]
    cuts = st["main"]["iter_cuts"]
    st = st["value"]
    Memento.info(_LOGGER, @sprintf("┃ %s%4i%6i │%11.3e%12.3e%12.3e │%11.3e ┃", st["current_best"] ? '•' : ' ', iter, cuts, st["inv_cost"], st["op_cost"], st["sol_value"], st["ub"]))
end
