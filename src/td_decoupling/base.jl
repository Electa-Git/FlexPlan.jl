function run_td_decoupling!(
        t_data::Dict{String,<:Any},
        d_data::Dict{String,<:Any},
        t_model_type::Type,
        d_model_type::Type{BF},
        optimizer::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        t_solution_processors::Vector{<:Function} = Function[],
        d_solution_processors::Vector{<:Function} = Function[],
        t_setting::Dict{String,Any} = Dict{String,Any}(),
        d_setting::Dict{String,Any} = Dict{String,Any}(),
    ) where BF <: _PM.AbstractBFModel

    # Check that transmission and distribution network ids are different.
    if !isempty(intersect(Set(id for (id,nw) in t_data["nw"]), Set(id for (id,nw) in d_data["nw"])))
        Memento.error(_LOGGER, "Transmission and distribution data contain networks having the same IDs.")
    end

    number_of_dist_networks = _FP.dim_length(d_data, :sub_nw)

    # Compute surrogate models of distribution networks and attach them to transmission network
    start_time = time()
    for s in 1:number_of_dist_networks
        Memento.debug(_LOGGER, "computing surrogate model $s of $number_of_dist_networks...")
        data = _FP.slice_multinetwork(d_data; sub_nw=s)
        sol_up, sol_base, sol_down = probe_distribution_flexibility!(data; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting)
        surrogate_distribution = calc_surrogate_model(data, sol_up, sol_base, sol_down)
        attach_surrogate_distribution!(t_data, surrogate_distribution)
    end
    Memento.debug(_LOGGER, "surrogate models of $number_of_dist_networks distribution networks computed in $(round(Int,time()-start_time)) seconds")

    # Compute planning of transmission network
    start_time = time()
    t_sol = run_td_decoupling_model(t_data; model_type=t_model_type, optimizer, build_method, ref_extensions=t_ref_extensions, solution_processors=t_solution_processors, setting=t_setting)
    Memento.debug(_LOGGER, "planning of transmission network computed in $(round(Int,time()-start_time)) seconds")

    return t_sol
end
