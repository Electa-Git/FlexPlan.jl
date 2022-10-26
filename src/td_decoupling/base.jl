"""
    run_td_decoupling(t_data, d_data, t_model_type, d_model_type, t_optimizer, d_optimizer, build_method; <keyword_arguments>)

Solve the planning of a transmission and distribution (T&D) system by decoupling the grid levels.

The T&D decoupling procedure is aimed at reducing computation time with respect to the
combined T&D model by solving the transmission and distribution parts of the network
separately.
It consists of the following steps:
1. compute a surrogate model of distribution networks;
2. optimize planning of transmission network using surrogate distribution networks;
3. fix power exchanges between T&D and optimize planning of distribution networks.
The procedure introduces approximations, therefore the solution cost is higher than that of
the combined T&D model.

# Arguments

- `t_data::Dict{String,Any}`: data dictionary for transmission network.
- `d_data::Vector{Dict{String,Any}}`: vector of data dictionaries, one for each distribution
  network. Each data dictionary must have a `t_bus` key indicating the transmission network
  bus id to which the distribution network is to be connected.
- `t_model_type::Type{<:PowerModels.AbstractPowerModel}`.
- `d_model_type::Type{<:PowerModels.AbstractPowerModel}`.
- `t_optimizer::Union{JuMP.MOI.AbstractOptimizer,JuMP.MOI.OptimizerWithAttributes}`:
  optimizer for transmission network. It has to solve a MILP problem and can exploit
  multi-threading.
- `d_optimizer::Union{JuMP.MOI.AbstractOptimizer,JuMP.MOI.OptimizerWithAttributes}`:
  optimizer for distribution networks. It has to solve 2 MILP and 4 LP problems per
  distribution network; since multi-threading is used to run optimizations of different
  distribution networks in parallel, it is better for this optimizer to be single-threaded.
- `build_method::Function`.
- `t_ref_extensions::Vector{<:Function} = Function[]`.
- `d_ref_extensions::Vector{<:Function} = Function[]`.
- `t_solution_processors::Vector{<:Function} = Function[]`.
- `d_solution_processors::Vector{<:Function} = Function[]`.
- `t_setting::Dict{String,<:Any} = Dict{String,Any}()`.
- `d_setting::Dict{String,<:Any} = Dict{String,Any}()`.
- `direct_model = false`: whether to construct JuMP models using `JuMP.direct_model()`
  instead of `JuMP.Model()`. Note that `JuMP.direct_model` is only supported by some
  solvers.
"""
function run_td_decoupling(
        t_data::Dict{String,Any},
        d_data::Vector{Dict{String,Any}},
        t_model_type::Type{<:_PM.AbstractPowerModel},
        d_model_type::Type{<:_PM.AbstractPowerModel},
        t_optimizer::Union{JuMP.MOI.AbstractOptimizer, JuMP.MOI.OptimizerWithAttributes},
        d_optimizer::Union{JuMP.MOI.AbstractOptimizer, JuMP.MOI.OptimizerWithAttributes},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        t_solution_processors::Vector{<:Function} = Function[],
        d_solution_processors::Vector{<:Function} = Function[],
        t_setting::Dict{String,<:Any} = Dict{String,Any}(),
        d_setting::Dict{String,<:Any} = Dict{String,Any}(),
        direct_model = false,
    )

    start_time = time()
    nw_id_set = Set(id for (id,nw) in t_data["nw"])
    d_data = deepcopy(d_data)
    number_of_distribution_networks = length(d_data)

    # Data preparation and checks
    for s in 1:number_of_distribution_networks
        data = d_data[s]
        d_gen_id = _FP.get_reference_gen(data)
        _FP.add_dimension!(data, :sub_nw, Dict(1 => Dict{String,Any}("t_bus"=>data["t_bus"], "d_gen"=>d_gen_id)))
        delete!(data, "t_bus")

        # Check that transmission and distribution network ids are the same
        if Set(id for (id,nw) in data["nw"]) ≠ nw_id_set
            Memento.error(_LOGGER, "Networks in transmission and distribution data dictionaries must have the same IDs.")
        end

        # Warn if cost for energy exchanged between transmission and distribution network is zero.
        for (n,nw) in data["nw"]
            d_gen = nw["gen"]["$d_gen_id"]
            if d_gen["ncost"] < 2 || d_gen["cost"][end-1] ≤ 0.0
                Memento.warn(_LOGGER, "Nonpositive cost detected for energy exchanged between transmission and distribution network $s. This may result in excessive usage of storage devices.")
                break
            end
        end

        # Notify if any storage devices have zero self-discharge rate.
        raise_warning = false
        for n in _FP.nw_ids(data; hour=1, scenario=1)
            for (st,storage) in get(data["nw"]["$n"], "storage", Dict())
                if storage["self_discharge_rate"] == 0.0
                    raise_warning = true
                    break
                end
            end
            for (st,storage) in get(data["nw"]["$n"], "ne_storage", Dict())
                if storage["self_discharge_rate"] == 0.0
                    raise_warning = true
                    break
                end
            end
            if raise_warning
                Memento.notice(_LOGGER, "Zero self-discharge rate detected for a storage device in distribution network $s. The model may have multiple optimal solutions.")
                break
            end
        end
    end

    surrogate_distribution = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
    surrogate_components = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
    exchanged_power = Vector{Dict{String,Float64}}(undef, number_of_distribution_networks)
    d_result = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)

    # Compute surrogate models of distribution networks and attach them to transmission network
    start_time_surr = time()
    Threads.@threads for s in 1:number_of_distribution_networks
        Memento.trace(_LOGGER, "computing surrogate model $s of $number_of_distribution_networks...")
        sol_up, sol_base, sol_down = probe_distribution_flexibility!(d_data[s]; model_type=d_model_type, optimizer=d_optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, direct_model)
        surrogate_distribution[s] = calc_surrogate_model(d_data[s], sol_up, sol_base, sol_down)
    end
    for s in 1:number_of_distribution_networks
        surrogate_components[s] = attach_surrogate_distribution!(t_data, surrogate_distribution[s])
    end
    Memento.debug(_LOGGER, "surrogate models of $number_of_distribution_networks distribution networks computed in $(round(time()-start_time_surr; sigdigits=3)) seconds")

    # Compute planning of transmission network
    start_time_t = time()
    t_result = run_td_decoupling_model(t_data; model_type=t_model_type, optimizer=t_optimizer, build_method, ref_extensions=t_ref_extensions, solution_processors=t_solution_processors, setting=t_setting, return_solution=false, direct_model)
    t_sol = t_result["solution"]
    t_objective = calc_t_objective(t_result, t_data, surrogate_components)
    for s in 1:number_of_distribution_networks
        exchanged_power[s] = calc_exchanged_power(surrogate_components[s], t_sol)
        remove_attached_distribution!(t_sol, t_data, surrogate_components[s])
    end
    Memento.debug(_LOGGER, "planning of transmission network computed in $(round(time()-start_time_t; sigdigits=3)) seconds")

    # Compute planning of distribution networks
    start_time_d = time()
    Threads.@threads for s in 1:number_of_distribution_networks
        Memento.trace(_LOGGER, "planning distribution network $s of $number_of_distribution_networks...")
        apply_td_coupling_power_active_with_zero_cost!(d_data[s], t_data, exchanged_power[s])
        d_result[s] = run_td_decoupling_model(d_data[s]; model_type=d_model_type, optimizer=d_optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, return_solution=false, direct_model)
    end
    d_objective = [d_res["objective"] for d_res in d_result]
    Memento.debug(_LOGGER, "planning of $number_of_distribution_networks distribution networks computed in $(round(time()-start_time_d; sigdigits=3)) seconds")

    result = Dict{String,Any}(
        "t_solution" => t_sol,
        "d_solution" => [d_res["solution"] for d_res in d_result],
        "t_objective" => t_objective,
        "d_objective" => d_objective,
        "objective" => t_objective + sum(d_objective; init=0.0),
        "solve_time" => time()-start_time
    )

    return result
end

"Run a model, ensure it is solved to optimality (error otherwise), return solution."
function run_td_decoupling_model(data::Dict{String,Any}; model_type::Type, optimizer, build_method::Function, ref_extensions, solution_processors, setting, relax_integrality=false, return_solution::Bool=true, direct_model=false, kwargs...)
    start_time = time()
    Memento.trace(_LOGGER, "┌ running $(String(nameof(build_method)))...")
    if direct_model
        result = _PM.run_model(
            data, model_type, nothing, build_method;
            ref_extensions,
            solution_processors,
            multinetwork = true,
            relax_integrality,
            setting,
            jump_model = JuMP.direct_model(optimizer),
            kwargs...
        )
    else
        result = _PM.run_model(
            data, model_type, optimizer, build_method;
            ref_extensions,
            solution_processors,
            multinetwork = true,
            relax_integrality,
            setting,
            kwargs...
        )
    end
    Memento.trace(_LOGGER, "└ solved in $(round(time()-start_time;sigdigits=3)) seconds (of which $(round(result["solve_time"];sigdigits=3)) seconds for solver)")
    if result["termination_status"] ∉ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Unable to solve $(String(nameof(build_method))) ($(result["optimizer"]) termination status: $(result["termination_status"]))")
    end
    return return_solution ? result["solution"] : result
end
