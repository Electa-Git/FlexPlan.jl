# Classical implementation of Benders decomposition

"""
    Classical <: BendersAlgorithm

Parameters for classical implementation of Benders decomposition:
- `obj_rtol`: stop when `(ub-lb)/abs(ub) < obj_rtol`, where `ub` and `lb` are the upper and
  lower bounds of the optimal solution value. Default: `sqrt(eps())`.
- `max_iter`: maximum number of iterations before stopping. Default: 1000.
- `tightening_rtol`: add an optimality cut only if
  `(sp_obj-sp_obj_lb)/abs(sp_obj) > tightening_rtol`, where `sp_obj` is the objective
  function value of the secondary problem and and `sp_obj_lb` is the value of the
  corresponding surrogate function. Default: `sqrt(eps())`.
- `sp_obj_lb_min`: constant term of the initial optimality cut, which prevents the main
  problem from being unbounded at the beginning. Default: `-1e12`."
- `silent`: require the solvers to produce no output; take precedence over any other
  attribute controlling verbosity. Default: `true`.
"""
struct Classical <: BendersAlgorithm
    @benders_fields
    obj_rtol::Float64
end

function Classical(;
        obj_rtol = sqrt(eps()),
        max_iter = 1000,
        tightening_rtol = sqrt(eps()),
        sp_obj_lb_min = -1e12,
        silent = true
    )
    Classical(
        max_iter,
        tightening_rtol,
        sp_obj_lb_min,
        silent,
        obj_rtol
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
        main_opt::Union{JuMP.MOI.AbstractOptimizer, JuMP.MOI.OptimizerWithAttributes},
        sec_opt::Union{JuMP.MOI.AbstractOptimizer, JuMP.MOI.OptimizerWithAttributes},
        main_bm::Function,
        sec_bm::Function;
        ref_extensions::Vector{<:Function} = Function[],
        solution_processors::Vector{<:Function} = Function[],
        kwargs...
    )

    time_procedure_start = time()
    Memento.debug(_LOGGER, "Classical Benders decomposition started. Available threads: $(Threads.nthreads()).")

    pm_main, pm_sec, num_sp, sp_obj_lb_var = instantiate_model(algo, data, model_type, main_opt, sec_opt, main_bm, sec_bm; ref_extensions, kwargs...)

    ub = Inf
    lb = -Inf
    iter = 0
    current_best = true
    best_main_var_values = nothing
    stat = Dict{Int,Any}()
    time_build = time() - time_procedure_start

    while true
        time_iteration_start = time()
        iter += 1

        time_main_start = time()
        JuMP.optimize!(pm_main.model)
        check_solution_main(pm_main)
        main_var_values = get_var_values(pm_main)
        time_main = time() - time_main_start

        time_sec_start = time()
        fix_and_optimize_secondary!(pm_sec, main_var_values)
        time_sec = time() - time_sec_start

        if iter == 1
            if !JuMP.has_duals(first(pm_sec).model) # If this check passes here, no need to check again in subsequent iterations.
                Memento.error(_LOGGER, "Solver $(JuMP.solver_name(first(pm_sec).model)) is unable to provide dual values.")
            end
            Memento.info(_LOGGER, "┏━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┯━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓")
            Memento.info(_LOGGER, "┃ iter.  cuts │  inv. cost  oper. cost    solution │         UB          LB    rel. gap ┃")
            Memento.info(_LOGGER, "┠─────────────┼────────────────────────────────────┼────────────────────────────────────┨")
        end

        inv_cost, op_cost, sol_value, rel_tightening, lb = calc_iter_result(algo, pm_main, pm_sec, sp_obj_lb_var)
        if sol_value < ub
            ub = sol_value
            current_best = true
            best_main_var_values = main_var_values
        else
            current_best = false
        end
        rel_gap = (ub-lb)/abs(ub)
        stop = rel_gap <= algo.obj_rtol || iter == algo.max_iter
        if stop
            iter_cuts = 0
        else
            iter_cuts = add_optimality_cuts!(pm_main, pm_sec, algo, num_sp, sp_obj_lb_var, main_var_values, rel_tightening)
        end
        time_iteration = time() - time_iteration_start # Time spent after this line is not measured
        record_statistics!(stat, algo, iter, iter_cuts, inv_cost, op_cost, sol_value, ub, lb, rel_gap, current_best, main_var_values, pm_main, pm_sec, time_main, time_sec, time_iteration)

        if stop
            if rel_gap <= algo.obj_rtol
                Memento.info(_LOGGER, "┠─────────────┴────────────────────────────────────┴────────────────────────────────────┨")
                Memento.info(_LOGGER, "┃                          Stopping: optimal within tolerance                     ▴     ┃")
                Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            elseif iter == algo.max_iter
                iter +=1 # To later distinguish whether the procedure reached optimality exactly after algo.max_iter iterations (above case) or did not reach optimality (this case)
                Memento.info(_LOGGER, "┠─────────────┴────────────────────────────────────┴────────────────────────────────────┨")
                Memento.info(_LOGGER, "┃   ▴                       Stopping: iteration limit reached                           ┃")
                Memento.info(_LOGGER, "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛")
            end
            break
        end
    end

    if !current_best
        fix_main_var_values!(pm_main, best_main_var_values)
        JuMP.optimize!(pm_main.model)
        check_solution_main(pm_main)
        fix_and_optimize_secondary!(pm_sec, best_main_var_values)
    end
    solution = build_solution(pm_main, pm_sec, solution_processors)
    termination_status = iter > algo.max_iter ? JuMP.ITERATION_LIMIT : JuMP.OPTIMAL
    build_result(ub, lb, solution, termination_status, stat, time_procedure_start, time_build)
end

function calc_iter_result(algo::Classical, pm_main, pm_sec, sp_obj_lb_var)
    mp_obj = JuMP.objective_value(pm_main.model)
    sp_obj = [JuMP.objective_value(pm.model) for pm in pm_sec]
    sp_obj_lb = [JuMP.value(lb) for lb in sp_obj_lb_var]
    rel_tightening = (sp_obj .- sp_obj_lb) ./ abs.(sp_obj)
    inv_cost = mp_obj - sum(sp_obj_lb)
    op_cost = sum(sp_obj)
    sol_value = inv_cost + op_cost
    lb = mp_obj
    return inv_cost, op_cost, sol_value, rel_tightening, lb
end

function add_optimality_cuts!(pm_main, pm_sec, algo::Classical, num_sp, sp_obj_lb_var, main_var_values, rel_tightening)
    iter_cuts = 0
    for p in 1:num_sp
        if rel_tightening[p] > algo.tightening_rtol
            iter_cuts += 1
            optimality_cut_expr = calc_optimality_cut(pm_main, pm_sec[p], main_var_values)
            JuMP.@constraint(pm_main.model, sp_obj_lb_var[p] >= optimality_cut_expr)
        end
    end
    return iter_cuts
end

function log_statistics(algo::Classical, st)
    iter = st["iter"]
    cuts = st["main"]["iter_cuts"]
    st = st["value"]
    Memento.info(_LOGGER, @sprintf("┃ %s%4i%6i │%11.3e%12.3e%12.3e │%11.3e%12.3e%12.3e ┃", st["current_best"] ? '•' : ' ', iter, cuts, st["inv_cost"], st["op_cost"], st["sol_value"], st["ub"], st["lb"], st["rel_gap"]))
end
