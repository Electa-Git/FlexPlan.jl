function run_td_decoupling(
        t_data::Dict{String,Any},
        d_data::Vector{Dict{String,Any}},
        t_model_type::Type{<:_PM.AbstractPowerModel},
        d_model_type::Type{<:_PM.AbstractPowerModel},
        t_optimizer::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        d_optimizer::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
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

    # Check that transmission and distribution network ids are the same
    nw_id_set = Set(id for (id,nw) in t_data["nw"])
    for data in d_data
        if Set(id for (id,nw) in data["nw"]) ≠ nw_id_set
            Memento.error(_LOGGER, "Networks in transmission and distribution data dictionaries must have the same IDs.")
        end
    end

    d_data = deepcopy(d_data)
    number_of_distribution_networks = length(d_data)
    surrogate_distribution = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
    surrogate_components = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
    exchanged_power = Vector{Dict{String,Float64}}(undef, number_of_distribution_networks)
    d_result = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)

    # Compute surrogate models of distribution networks and attach them to transmission network
    start_time_surr = time()
    Threads.@threads for s in 1:number_of_distribution_networks
        Memento.trace(_LOGGER, "computing surrogate model $s of $number_of_distribution_networks...")
        data = d_data[s]
        _FP.add_dimension!(data, :sub_nw, Dict(1 => Dict{String,Any}("t_bus"=>data["t_bus"], "d_gen"=>_FP.get_reference_gen(data))))
        delete!(data, "t_bus")
        sol_up, sol_base, sol_down = probe_distribution_flexibility!(data; model_type=d_model_type, optimizer=d_optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, direct_model)
        surrogate_distribution[s] = calc_surrogate_model(data, sol_up, sol_base, sol_down)
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
