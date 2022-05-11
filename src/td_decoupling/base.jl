function run_td_decoupling!(
        t_data::Dict{String,Any},
        d_data::Vector{Dict{String,Any}},
        t_model_type::Type,
        d_model_type::Type{BF},
        optimizer::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        t_solution_processors::Vector{<:Function} = Function[],
        d_solution_processors::Vector{<:Function} = Function[],
        t_setting::Dict{String,<:Any} = Dict{String,Any}(),
        d_setting::Dict{String,<:Any} = Dict{String,Any}(),
        direct_model = false,
    ) where BF <: _PM.AbstractBFModel

    start_time = time()

    # Check that transmission and distribution network ids are different.
    nw_id_set = Set(id for (id,nw) in t_data["nw"])
    for data in d_data
        if Set(id for (id,nw) in data["nw"]) ≠ nw_id_set
            Memento.error(_LOGGER, "Networks in transmission and distribution data dictionaries must have the same IDs.")
        end
    end

    number_of_dist_networks = length(d_data)
    surrogate_components = Vector{Dict{String,Any}}(undef, number_of_dist_networks)
    exchanged_power = Vector{Dict{String,Float64}}(undef, number_of_dist_networks)
    d_result = Vector{Dict{String,Any}}(undef, number_of_dist_networks)

    # Compute surrogate models of distribution networks and attach them to transmission network
    start_time_surr = time()
    for s in 1:number_of_dist_networks
        Memento.debug(_LOGGER, "computing surrogate model $s of $number_of_dist_networks...")
        sol_up, sol_base, sol_down = probe_distribution_flexibility!(d_data[s]; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, direct_model)
        surrogate_distribution = calc_surrogate_model(d_data[s], sol_up, sol_base, sol_down)
        surrogate_components[s] = attach_surrogate_distribution!(t_data, surrogate_distribution)
    end
    Memento.debug(_LOGGER, "surrogate models of $number_of_dist_networks distribution networks computed in $(round(Int,time()-start_time_surr)) seconds")

    # Compute planning of transmission network
    start_time_t = time()
    t_result = run_td_decoupling_model(t_data; model_type=t_model_type, optimizer, build_method, ref_extensions=t_ref_extensions, solution_processors=t_solution_processors, setting=t_setting, return_solution=false, direct_model)
    t_sol = t_result["solution"]
    t_objective = calc_t_objective(t_result, t_data, surrogate_components)
    for s in 1:number_of_dist_networks
        exchanged_power[s] = calc_exchanged_power(surrogate_components[s], t_sol)
        remove_attached_distribution!(t_sol, t_data, surrogate_components[s])
    end
    Memento.debug(_LOGGER, "planning of transmission network computed in $(round(Int,time()-start_time_t)) seconds")

    # Compute planning of distribution networks
    start_time_d = time()
    for s in 1:number_of_dist_networks
        Memento.debug(_LOGGER, "planning distribution network $s of $number_of_dist_networks...")
        data = deepcopy(d_data[s])
        apply_td_coupling_power_active_with_zero_cost!(data, t_data, exchanged_power[s])
        d_result[s] = run_td_decoupling_model(data; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, return_solution=false, direct_model)
    end
    d_objective = [d_res["objective"] for d_res in d_result]
    Memento.debug(_LOGGER, "planning of $number_of_dist_networks distribution networks computed in $(round(Int,time()-start_time_d)) seconds")

    result = Dict{String,Any}(
        "t_solution" => t_sol,
        "d_solution" => [d_res["solution"] for d_res in d_result],
        "t_objective" => t_objective,
        "d_objective" => d_objective,
        "objective" => t_objective + sum(d_objective),
        "solve_time" => time()-start_time
    )

    return result
end
