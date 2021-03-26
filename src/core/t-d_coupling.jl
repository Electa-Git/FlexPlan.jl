# Transmission & distribution coupling functions



## Functions replacing PowerModels or InfrastructureModels functions

""
function run_model(
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
        kwargs...
    ) where BF <: _PM.AbstractBFModel

    # Check that transmission and distribution network ids are different.
    if !isempty(intersect(Set(id for (id,nw) in t_data["nw"]), Set(id for (id,nw) in d_data["nw"])))
        Memento.error(_LOGGER, "Transmission and distribution data contain networks having the same IDs.")
    end

    # Instantiate models.
    start_time = time()
    t_pm, d_pm = instantiate_model(t_data, d_data, t_model_type, d_model_type, build_method; t_ref_extensions, d_ref_extensions, kwargs...)
    Memento.debug(_LOGGER, "combined T&D model build time: $(time() - start_time)")

    start_time = time()

    # Solve the optimization model and store the transmission result.
    t_result = _IM.optimize_model!(t_pm; optimizer, solution_processors=t_solution_processors)

    # Build the distribution result using the same model as above.
    d_result = _IM.build_result(d_pm, t_result["solve_time"]; solution_processors=d_solution_processors)

    # The asymmetric code above for building results produces inaccurate debugging messages;
    # this behavior can be fixed by writing a custom optimize_model!() that takes 2 models.

    Memento.debug(_LOGGER, "combined T&D model solution time: $(time() - start_time)")

    # Combine the result objects.
    result = t_result # All fields are pairwise equal, except for "solution".
    solution = result["solution"]
    for (k,v) in d_result["solution"]
        if k == "nw"
            # Merge transmission and distribution "nw" fields.
            # Network ids do not clash (checked before model instantiation).
            solution["nw"] = merge(solution["nw"], v)
        else
            if solution[k] != v
                Memento.warning(_LOGGER, "Transmission and distribution solutions differ on key \"$k\"; only transmission value is kept.")
            end
        end
    end

    return result
end

""
function instantiate_model(
        t_data::Dict{String,<:Any},
        d_data::Dict{String,<:Any},
        t_model_type::Type,
        d_model_type::Type{BF},
        build_method::Function;
        t_ref_extensions::Vector{<:Function} = Function[],
        d_ref_extensions::Vector{<:Function} = Function[],
        kwargs...
    ) where BF <: _PM.AbstractBFModel

    # Instantiate the transmission PowerModels struct, without building the model.
    t_pm = _PM.instantiate_model(t_data, t_model_type, method->nothing; ref_extensions=t_ref_extensions, kwargs...)

    # Instantiate the distribution PowerModels struct, without building the model.
    # Distribution and transmission structs share the same JuMP model. The `jump_model` parameter is used by _IM.InitializeInfrastructureModel().
    d_pm = _PM.instantiate_model(d_data, d_model_type, method->nothing; ref_extensions=d_ref_extensions, jump_model=t_pm.model, kwargs...)

    # Build the combined model.
    build_method(t_pm, d_pm)

    return t_pm, d_pm
end



## Functions that manipulate data structures

"""
Add to distribution single-network data structures the data needed for T&D coupling.

- Add to distribution network data structure a coupling generator connected to the reference bus; if
  it already exists, overwrite all its parameters except cost.
- Define a bound on reactive power exchanged between transmission and distribution networks: it is
  computed as a fraction `qs_ratio_bound` of the rated power of the distribution network (based on
  the rated power of existing and candidate branches connected to the reference bus); default value
  is 0.48 as per “Network Code on Demand Connection” – Commission Regulation (EU) 2016/1388.
- Add to distribution network data structure the key `td_coupling` that contains:
  - `d_gen`: the id of the coupling generator of distribution network;
  - `qs_ratio_bound`: the aforementioned allowable fraction of the rated power;
  - `sub_nw`: an unique integer identifier of the physical distribution network.

Return `d_gen`.

This function is intended to be the last that edits distribution single-network data structures: it
should be called just before `multinetwork_data()`.
"""
function add_td_coupling_data!(d_data::Dict{String,Any}; sub_nw::Int, qs_ratio_bound::Float64=0.48)

    # Get the reference bus id
    d_ref_buses = [b for (b,bus) in d_data["bus"] if bus["bus_type"] == 3]
    if length(d_ref_buses) != 1
        Memento.error(_LOGGER, "Distribution network data must have 1 ref bus, but $(length(d_ref_buses)) are present.")
    end
    d_ref_bus = parse(Int, first(d_ref_buses))

    # Get a list of the ids of generators connected to the reference bus
    d_ref_gens = [g for (g,gen) in d_data["gen"] if gen["gen_bus"] == d_ref_bus]
    if length(d_ref_gens) > 1
        Memento.error(_LOGGER, "Distribution network data must have 0 or 1 generator connected to ref bus, but $(length(d_ref_gens)) are present.")
    end
    
    # Define an upper bound on the rated apparent power based on the rated power of existing and candidate branches connected to the reference bus
    d_s_rate = (
          sum(branch["rate_a"] for (b,branch) in d_data["branch"]    if (branch["f_bus"]==d_ref_bus || branch["t_bus"]==d_ref_bus) && branch["br_status"]==1) # In t_bus here, the t stands for "to" (not for "transmission" as in the rest of the function)
        + sum(branch["rate_a"] for (b,branch) in d_data["ne_branch"] if (branch["f_bus"]==d_ref_bus || branch["t_bus"]==d_ref_bus) && branch["br_status"]==1) # In t_bus here, the t stands for "to" (not for "transmission" as in the rest of the function)
    )

    # Add a coupling generator connected to d_ref_bus (or use existing one) to model the transmission network
    if isempty(d_ref_gens)
        d_gen_idx = length(d_data["gen"]) + 1 # Assumes that gens have contiguous indices starting from 1, as should be
        d_data["gen"]["$d_gen_idx"] = Dict{String,Any}(
            "gen_bus" => d_ref_bus,
            "index"   => d_gen_idx,
            "model"   => 2, # Cost model (2 => polynomial cost)
            "ncost"   => 0, # Number of cost coefficients
            "cost"    => Any[]
        )
    else
        d_gen_idx = parse(Int, first(d_ref_gens))
    end

    # Set coupling generator parameters
    d_gen = d_data["gen"]["$d_gen_idx"]
    d_gen["mbase"]      = d_data["baseMVA"]
    d_gen["pmin"]       = -d_s_rate
    d_gen["pmax"]       =  d_s_rate
    d_gen["qmin"]       = -d_s_rate
    d_gen["qmax"]       =  d_s_rate
    d_gen["gen_status"] = 1

    # Store the T&D coupling parameters
    d_data["td_coupling"] = Dict{String,Any}()
    d_data["td_coupling"]["qs_ratio_bound"] = qs_ratio_bound
    d_data["td_coupling"]["sub_nw"] = sub_nw
    d_data["td_coupling"]["d_gen"] = d_gen_idx

end

"""
Add to transmission and distribution single-network data structures the data needed for T&D coupling.

In addition to `add_td_coupling_data!(d_data; sub_nw, qs_ratio_bound)`, do the following:
- Add to transmission network data structure a coupling generator connected to `t_bus`, that is the
  bus to which the distribution network is to be connected.
- Add to `td_coupling` dict of distribution network an entry `t_gen` for the id of the coupling
  generator of transmission network.

Return `t_gen`.

This function is intended to be the last that edits transmission and distribution single-network
data structures: it should be called just before `multinetwork_data()`.
"""
function add_td_coupling_data!(t_data::Dict{String,Any}, d_data::Dict{String,Any}; t_bus::Int, sub_nw::Int, qs_ratio_bound::Float64=0.48)

    d_gen_idx = add_td_coupling_data!(d_data; sub_nw, qs_ratio_bound)

    # Check that t_bus exists
    if !haskey(t_data["bus"], "$t_bus")
        Memento.error(_LOGGER, "Bus $t_bus does not exist in transmission network data.")
    end

    # Add a coupling generator connected to t_bus, to model the distribution network
    t_s_rate = (d_data["baseMVA"]/t_data["baseMVA"]) * d_data["gen"]["$d_gen_idx"]["pmax"]
    t_gen_idx = length(t_data["gen"]) + 1 # Assumes that gens have contiguous indices starting from 1, as should be
    t_data["gen"]["$t_gen_idx"] = Dict{String,Any}(
        "gen_bus"    => t_bus,
        "index"      => t_gen_idx,
        "mbase"      => t_data["baseMVA"],
        "pmin"       => -t_s_rate,
        "pmax"       =>  t_s_rate,
        "qmin"       => -t_s_rate,
        "qmax"       =>  t_s_rate,
        "gen_status" => 1,
        "model"      => 2, # Cost model (2 => polynomial cost)
        "ncost"      => 0, # Number of cost coefficients
        "cost"       => Any[]
    )

    # Add generator id to T&D coupling parameters
    d_data["td_coupling"]["t_gen"] = t_gen_idx

end



## Solution processors

"""
Add T&D coupling data to solution.

Report in `solution` the active and reactive power that distribution network `pm` exchanges with the
transmission network (positive if from transmission to distribution) in units of `baseMVA` of `pm`.
"""
function sol_td_coupling!(pm::_PM.AbstractBFModel, solution::Dict{String,Any})
    if haskey(solution, "nw")
        nws_sol = solution["nw"]
    else
        nws_sol = Dict("0" => solution)
    end

    for (nw, nw_sol) in nws_sol
        if !haskey(_PM.ref(pm, parse(Int,nw)), :td_coupling)
            Memento.error(_LOGGER, "T&D coupling data is missing from the model of nw $nw.")
        end
        d_gen = _PM.ref(pm, parse(Int,nw), :td_coupling, "d_gen")
        nw_sol["td_coupling"] = Dict{String,Any}()
        nw_sol["td_coupling"]["p"] = nw_sol["gen"]["$d_gen"]["pg"]
        nw_sol["td_coupling"]["q"] = nw_sol["gen"]["$d_gen"]["qg"]
    end
end



## Functions that group constraint templates, provided for convenience

"""
Connect each distribution nw to the corresponding transmission nw and apply coupling constraints.

The coupling constraint is applied to the two generators that each distribution nw indicates.
"""
function constraint_td_coupling(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel)
    t_nws = sort(collect(_PM.nw_ids(t_pm)))

    for (sub_nw, nw_ids) in d_pm.ref[:sub_nw]
        d_nws = sort(collect(nw_ids))
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
    t_gen = _PM.ref(d_pm, d_nw, :td_coupling, "t_gen") # Note: is defined in dist nw
    d_gen = _PM.ref(d_pm, d_nw, :td_coupling, "d_gen")
    t_mbase = _PM.ref(t_pm, t_nw, :gen, t_gen, "mbase")
    d_mbase = _PM.ref(d_pm, d_nw, :gen, d_gen, "mbase")

    constraint_td_coupling_power_balance_active(t_pm, d_pm, t_nw, d_nw, t_gen, d_gen, t_mbase, d_mbase)
    constraint_td_coupling_power_balance_reactive(t_pm, d_pm, t_nw, d_nw, t_gen, d_gen, t_mbase, d_mbase)
end

"""
Apply bounds on reactive power exchange at the point of common coupling (PCC) of a distribution nw.
"""
function constraint_td_coupling_power_reactive_bounds(d_pm::_PM.AbstractBFModel; nw::Int=d_pm.cnw)
    d_gen = _PM.ref(d_pm, nw, :td_coupling, "d_gen")

    constraint_td_coupling_power_reactive_bounds(d_pm, nw, d_gen)
end



## Constraint implementations

""
function constraint_td_coupling_power_balance_active(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mbase::Float64, d_mbase::Float64)
    t_p_in = _PM.var(t_pm, t_nw, :pg, t_gen)
    d_p_in = _PM.var(d_pm, d_nw, :pg, d_gen)
    JuMP.@constraint(t_pm.model, t_mbase*t_p_in + d_mbase*d_p_in == 0.0) # t_pm.model == d_pm.model
end

""
function constraint_td_coupling_power_balance_reactive(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mbase::Float64, d_mbase::Float64)
    t_q_in = _PM.var(t_pm, t_nw, :qg, t_gen)
    d_q_in = _PM.var(d_pm, d_nw, :qg, d_gen)
    JuMP.@constraint(t_pm.model, t_mbase*t_q_in + d_mbase*d_q_in == 0.0) # t_pm.model == d_pm.model
end

"Nothing to do because the transmission network model does not support reactive power."
function constraint_td_coupling_power_balance_reactive(t_pm::_PM.AbstractActivePowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mbase::Float64, d_mbase::Float64)
end

""
function constraint_td_coupling_power_reactive_bounds(d_pm::_PM.AbstractBFModel, d_nw::Int, d_gen::Int)

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

    qs_ratio_bound = _PM.ref(d_pm, d_nw, :td_coupling, "qs_ratio_bound") # Allowable fraction of rated apparent power

    q = _PM.var(d_pm, d_nw, :qg, d_gen) # Exchanged reactive power (positive if from T to D)

    JuMP.@constraint(d_pm.model, q <=  qs_ratio_bound*s_rate)
    JuMP.@constraint(d_pm.model, q >= -qs_ratio_bound*s_rate)

end
