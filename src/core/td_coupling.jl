# Transmission & distribution coupling functions



## Functions replacing PowerModels or InfrastructureModels functions

""
function run_model(
        t_data::Dict{String,Any},
        d_data::Vector{Dict{String,Any}},
        t_model_type::Type{<:_PM.AbstractPowerModel},
        d_model_type::Type{<:_PM.AbstractPowerModel},
        optimizer::Union{_MOI.AbstractOptimizer, _MOI.OptimizerWithAttributes},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        t_solution_processors::Vector{<:Function} = Function[],
        d_solution_processors::Vector{<:Function} = Function[],
        t_setting::Dict{String,<:Any} = Dict{String,Any}(),
        d_setting::Dict{String,<:Any} = Dict{String,Any}(),
        direct_model = false,
        kwargs...
    )

    start_time = time()
    number_of_nws = dim_length(t_data)
    number_of_dist_networks = length(d_data)

    # Check that transmission and distribution network ids are the same
    nw_id_set = Set(id for (id,nw) in t_data["nw"])
    for data in d_data
        if Set(id for (id,nw) in data["nw"]) ≠ nw_id_set
            Memento.error(_LOGGER, "Networks in transmission and distribution data dictionaries must have the same IDs.")
        end
    end

    t_data = deepcopy(t_data)

    # Merge distribution networks
    d_data_merged = deepcopy(first(d_data))
    shift_nws!(d_data_merged)
    add_dimension!(d_data_merged, :sub_nw, Dict(1 => Dict{String,Any}("t_bus"=>d_data_merged["t_bus"])))
    delete!(d_data_merged, "t_bus")
        for data in Iterators.drop(d_data, 1)
        data = deepcopy(data)
        shift_nws!(data, dim_length(d_data_merged)+number_of_nws)
        add_dimension!(data, :sub_nw, Dict(1 => Dict{String,Any}("t_bus"=>data["t_bus"])))
        delete!(data, "t_bus")
        merge_multinetworks!(d_data_merged, data, :sub_nw)
    end

    t_gens = add_td_coupling_generators!(t_data, d_data_merged)

    # Instantiate models
    start_time_instantiate = time()
    if direct_model
        t_pm, d_pm = instantiate_model(t_data, d_data_merged, t_model_type, d_model_type, build_method; t_ref_extensions, d_ref_extensions, t_setting, d_setting, jump_model=JuMP.direct_model(optimizer), kwargs...)
    else
        t_pm, d_pm = instantiate_model(t_data, d_data_merged, t_model_type, d_model_type, build_method; t_ref_extensions, d_ref_extensions, t_setting, d_setting, kwargs...)
    end
    Memento.debug(_LOGGER, "combined T&D model build time: $(time() - start_time_instantiate)")

    start_time_optimize = time()

    # Solve the optimization model and store the transmission result.
    t_result = _IM.optimize_model!(t_pm; optimizer, solution_processors=t_solution_processors)

    # Build the distribution result using the same model as above.
    d_result = _IM.build_result(d_pm, t_result["solve_time"]; solution_processors=d_solution_processors)

    # The asymmetric code above for building results produces inaccurate debugging messages;
    # this behavior can be fixed by writing a custom optimize_model!() that takes 2 models.

    # Remove coupling generators from transmission solution.
    for nw in values(t_result["solution"]["nw"])
        for t_gen in t_gens
            delete!(nw["gen"], string(t_gen))
        end
    end

    # Subdivide distribution result.
    if haskey(d_result["solution"], "nw") # It only happens if the problem is solved to optimality.
        d_nw_merged = d_result["solution"]["nw"]
        d_sol = Vector{Dict{String,Any}}(undef,number_of_dist_networks)
        d_sol_template = filter(pair->pair.first≠"nw", d_result["solution"])
        for s in 1:number_of_dist_networks
            d_sol[s] = copy(d_sol_template)
            nw = d_sol[s]["nw"] = Dict{String,Any}()
            for n in nw_ids(t_data)
                nw["$n"] = d_nw_merged["$(s*number_of_nws+n)"]
            end
        end
    else
        d_sol = Dict{String,Any}()
    end

    Memento.debug(_LOGGER, "combined T&D model solution time: $(time() - start_time_optimize)")

    result = t_result
    result["t_solution"] = t_result["solution"]
    delete!(result, "solution")
    result["d_solution"] = d_sol
    result["solve_time"] = time()-start_time

    return result
end

""
function instantiate_model(
        t_data::Dict{String,Any},
        d_data::Dict{String,Any},
        t_model_type::Type{<:_PM.AbstractPowerModel},
        d_model_type::Type{<:_PM.AbstractPowerModel},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        t_setting::Dict{String,<:Any} = Dict{String,Any}(),
        d_setting::Dict{String,<:Any} = Dict{String,Any}(),
        kwargs...
    )

    # Instantiate the transmission PowerModels struct, without building the model.
    t_pm = _PM.instantiate_model(t_data, t_model_type, method->nothing; ref_extensions=t_ref_extensions, setting=t_setting, kwargs...)

    # Instantiate the distribution PowerModels struct, without building the model.
    # Distribution and transmission structs share the same JuMP model. The `jump_model` parameter is used by _IM.InitializeInfrastructureModel().
    # `jump_model` comes after `kwargs...` to take precedence in cases where it is also defined in `kwargs...`.
    d_pm = _PM.instantiate_model(d_data, d_model_type, method->nothing; ref_extensions=d_ref_extensions, setting=d_setting, kwargs..., jump_model=t_pm.model)

    # Build the combined model.
    build_method(t_pm, d_pm)

    return t_pm, d_pm
end



## Functions that manipulate data structures

"""
    add_td_coupling_generators!(t_data, d_data)

Add and set T&D coupling generators.

For each network `n` in `d_data`:
- set the cost of distribution coupling generator to 0;
- add the transmission coupling generator;
- add to `dim_prop(d_data, `n`, :sub_nw)` the following entries:
  - `d_gen`: the id of the distribution coupling generator;
  - `t_gen`: the id of the transmission coupling generator.
Return a vector containing the ids of `t_gen`.

# Prerequisites
- Networks in `d_data` have exactly 1 reference bus 1 generator connected to it.
- A dimension `sub_nw` is defined for `d_data` and a property `t_bus` defines the id of the
  transmission network bus where the distribution network is attached.
"""
function add_td_coupling_generators!(t_data::Dict{String,Any}, d_data::Dict{String,Any})
    t_nw_ids = nw_ids(t_data)
    if !check_constant_number_of_generators(t_data, t_nw_ids)
        Memento.error(_LOGGER, "The number of generators in transmission network is not constant.")
    end

    number_of_distribution_networks = dim_length(d_data, :sub_nw)
    t_gens = Vector{Int}(undef, number_of_distribution_networks)

    for s in 1:number_of_distribution_networks
        d_nw_ids = nw_ids(d_data; sub_nw=s)
        if !check_constant_number_of_generators(d_data, d_nw_ids)
            Memento.error(_LOGGER, "The number of generators in distribution network $s is not constant.")
        end
        sub_nw = dim_prop(d_data, :sub_nw, s)

        # Get distribution coupling generator id and store it in `sub_nw`` properties
        d_gen_idx = sub_nw["d_gen"] = get_reference_gen(d_data, s)

        t_bus = sub_nw["t_bus"]

        # Compute transmission generator id
        t_gen_idx = length(first(values(t_data["nw"]))["gen"]) + 1 # Assumes that gens have contiguous indices starting from 1, as should be
        sub_nw["t_gen"] = t_gen_idx
        t_gens[s] = t_gen_idx

        for (t_n, d_n) in zip(t_nw_ids, d_nw_ids)

            t_nw = t_data["nw"]["$t_n"]
            d_nw = d_data["nw"]["$d_n"]

            # Set distribution coupling generator parameters
            d_gen = d_nw["gen"]["$d_gen_idx"]
            d_gen["dispatchable"] = true
            d_gen["model"]        = 2 # Cost model (2 => polynomial cost)
            d_gen["ncost"]        = 0 # Number of cost coefficients
            d_gen["cost"]         = Any[]

            # Check that t_bus exists
            if !haskey(t_nw["bus"], "$t_bus")
                Memento.error(_LOGGER, "Bus $t_bus does not exist in nw $t_n of transmission network data.")
            end

            # Add transmission coupling generator
            mva_base_ratio = d_nw["baseMVA"] / t_nw["baseMVA"]
            t_gen = t_nw["gen"]["$t_gen_idx"] = Dict{String,Any}(
                "gen_bus"      => t_bus,
                "index"        => t_gen_idx,
                "dispatchable" => true,
                "pmin"         => -d_gen["pmax"] * mva_base_ratio,
                "pmax"         => -d_gen["pmin"] * mva_base_ratio,
                "gen_status"   => 1,
                "model"        => 2, # Cost model (2 => polynomial cost)
                "ncost"        => 0, # Number of cost coefficients
                "cost"         => Any[]
            )
            if haskey(d_gen, "qmax")
                t_gen["qmin"] = -d_gen["qmax"] * mva_base_ratio
                t_gen["qmax"] = -d_gen["qmin"] * mva_base_ratio
            end
        end
    end

    return t_gens
end



## Utility functions

function check_constant_number_of_generators(data::Dict{String,Any}, nws::Vector{Int})
    data_nw = data["nw"]
    first_n, rest = Iterators.peel(nws)
    first_n_gen_length = length(data_nw["$first_n"]["gen"])
    for n in rest
        if length(data_nw["$n"]["gen"]) ≠ first_n_gen_length
            return false
        end
    end
    return true
end

function get_reference_gen(data::Dict{String,Any}, s::Int=1)
    nws = nw_ids(data; sub_nw=s)
    first_nw = data["nw"][ string(first(nws)) ]

    # Get the id of the only reference bus
    ref_buses = [b for (b,bus) in first_nw["bus"] if bus["bus_type"] == 3]
    if length(ref_buses) != 1
        Memento.error(_LOGGER, "Distribution network must have 1 reference bus, but $(length(ref_buses)) are present.")
    end
    ref_bus = parse(Int, first(ref_buses))

    # Get the id of the only generator connected to the reference bus
    ref_gens = [g for (g,gen) in first_nw["gen"] if gen["gen_bus"] == ref_bus]
    if length(ref_gens) ≠ 1
        Memento.error(_LOGGER, "Distribution network must have 1 generator connected to reference bus, but $(length(ref_gens)) are present.")
    end
    return parse(Int, first(ref_gens))
end



## Solution processors

"""
    sol_td_coupling!(pm, solution)

Add T&D coupling data to `solution` and remove the fake generator from `solution`.

Report in `solution["td_coupling"]["p"]` and `solution["td_coupling"]["q"]` the active and
reactive power that distribution network `pm` exchanges with the transmission network
(positive if from transmission to distribution) in units of `baseMVA` of `pm`.

Delete from `solution` the generator representing the transmission network, so that only the
actual generators remain in `solution["gen"]`.
"""
function sol_td_coupling!(pm::_PM.AbstractBFModel, solution::Dict{String,Any})
    solution = _PM.get_pm_data(solution)
    if haskey(solution, "nw")
        nws_sol = solution["nw"]
    else
        nws_sol = Dict("0" => solution)
    end

    for (nw, nw_sol) in nws_sol
        n = parse(Int, nw)
        if !(haskey(dim_prop(pm), :sub_nw) && haskey(dim_prop(pm, n, :sub_nw), "d_gen"))
            Memento.error(_LOGGER, "T&D coupling data is missing from the model of nw $nw.")
        end
        d_gen = string(dim_prop(pm, n, :sub_nw, "d_gen"))
        nw_sol["td_coupling"] = Dict{String,Any}()
        nw_sol["td_coupling"]["p"] = nw_sol["gen"][d_gen]["pg"]
        nw_sol["td_coupling"]["q"] = nw_sol["gen"][d_gen]["qg"]
        delete!(nw_sol["gen"], d_gen)
    end
end



## Functions that group constraint templates, provided for convenience

"""
Connect each distribution nw to the corresponding transmission nw and apply coupling constraints.

The coupling constraint is applied to the two generators that each distribution nw indicates.
"""
function constraint_td_coupling(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel)
    t_nws = nw_ids(t_pm)

    for s in keys(dim_prop(d_pm, :sub_nw))
        d_nws = nw_ids(d_pm; sub_nw = s)
        for i in 1:length(t_nws)
            t_nw = t_nws[i]
            d_nw = d_nws[i]

            constraint_td_coupling_power_balance(t_pm, d_pm, t_nw, d_nw)
        end
    end
end



## Constraint templates

"""
State the power conservation between a distribution nw and the corresponding transmission nw.
"""
function constraint_td_coupling_power_balance(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int)
    sub_nw = dim_prop(d_pm, d_nw, :sub_nw)
    t_gen = sub_nw["t_gen"]
    d_gen = sub_nw["d_gen"]
    t_mva_base = _PM.ref(t_pm, t_nw, :baseMVA)
    d_mva_base = _PM.ref(d_pm, d_nw, :baseMVA)

    constraint_td_coupling_power_balance_active(t_pm, d_pm, t_nw, d_nw, t_gen, d_gen, t_mva_base, d_mva_base)
    constraint_td_coupling_power_balance_reactive(t_pm, d_pm, t_nw, d_nw, t_gen, d_gen, t_mva_base, d_mva_base)
end

"""
Apply bounds on reactive power exchange at the point of common coupling (PCC) of a distribution nw, as allowable fraction of rated apparent power.
"""
function constraint_td_coupling_power_reactive_bounds(d_pm::_PM.AbstractBFModel, qs_ratio_bound::Real; nw::Int=_PM.nw_id_default)
    sub_nw = dim_prop(d_pm, nw, :sub_nw)
    d_gen = sub_nw["d_gen"]

    constraint_td_coupling_power_reactive_bounds(d_pm, nw, d_gen, qs_ratio_bound)
end



## Constraint implementations

""
function constraint_td_coupling_power_balance_active(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mva_base::Real, d_mva_base::Real)
    t_p_in = _PM.var(t_pm, t_nw, :pg, t_gen)
    d_p_in = _PM.var(d_pm, d_nw, :pg, d_gen)
    JuMP.@constraint(t_pm.model, t_mva_base*t_p_in + d_mva_base*d_p_in == 0.0) # t_pm.model == d_pm.model
end

""
function constraint_td_coupling_power_balance_reactive(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mva_base::Real, d_mva_base::Real)
    t_q_in = _PM.var(t_pm, t_nw, :qg, t_gen)
    d_q_in = _PM.var(d_pm, d_nw, :qg, d_gen)
    JuMP.@constraint(t_pm.model, t_mva_base*t_q_in + d_mva_base*d_q_in == 0.0) # t_pm.model == d_pm.model
end

"Nothing to do because the transmission network model does not support reactive power."
function constraint_td_coupling_power_balance_reactive(t_pm::_PM.AbstractActivePowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mva_base::Real, d_mva_base::Real)
end

""
function constraint_td_coupling_power_reactive_bounds(d_pm::_PM.AbstractBFModel, d_nw::Int, d_gen::Int, qs_ratio_bound::Real)

    # Compute the rated apparent power of the distribution network, based on the rated power of
    # existing and candidate branches connected to its reference bus. This value depends on the
    # indicator variables of both existing (if applicable) and candidate branches (i.e. whether they
    # are built or not).
    if haskey(_PM.var(d_pm, d_nw), :z_branch) # Some `branch`es can be replaced by `ne_branch`es
        z_branch = _PM.var(d_pm, d_nw, :z_branch)
        s_rate = (
            sum(branch["rate_a"] * get(z_branch, b, 1.0) for (b,branch) in _PM.ref(d_pm, d_nw, :frb_branch))
            + sum(branch["rate_a"] * _PM.var(d_pm, d_nw, :branch_ne, b) for (b,branch) in _PM.ref(d_pm, d_nw, :frb_ne_branch))
        )
    else # No `ne_branch`es at all
        s_rate = sum(branch["rate_a"] for (b,branch) in _PM.ref(d_pm, d_nw, :frb_branch))
    end

    q = _PM.var(d_pm, d_nw, :qg, d_gen) # Exchanged reactive power (positive if from T to D)

    JuMP.@constraint(d_pm.model, q <=  qs_ratio_bound*s_rate)
    JuMP.@constraint(d_pm.model, q >= -qs_ratio_bound*s_rate)
end
