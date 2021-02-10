# Transmission & distribution coupling functions


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

"""
Add to transmission and distribution single-network data structures the data needed for T&D coupling.

In transmission network data structure:
- add a generator connected to `t_bus`, that is the bus to which the distribution network is to be
  connected.

In distribution network data structure:
- add the key `t_coupling_gen` that stores the id of the newly added transmission generator;
- add the key `d_coupling_gen` that stores the id of the generator connected to the reference bus;
- add the key `sub_nw`, that is an unique integer identifier of the physical distribution network.

This function is intended to be the last that edits transmission and distribution single-network
data structures: it should be called just before `multinetwork_data()`.
"""
function add_td_coupling_data!(t_data::Dict{String,Any}, d_data::Dict{String,Any}; t_bus::Int, sub_nw::Int)

    ## Data extraction from distribution data

    # Get the reference bus id
    d_ref_buses = [b for (b,bus) in d_data["bus"] if bus["bus_type"] == 3]
    if length(d_ref_buses) != 1
        Memento.error(_LOGGER, "Distribution network data must have 1 ref bus, but $(length(d_ref_buses)) are present.")
    end
    d_ref_bus = parse(Int, first(d_ref_buses))

    # Get the id of generator connected to the reference bus
    d_ref_gens = [g for (g,gen) in d_data["gen"] if gen["gen_bus"] == d_ref_bus]
    if length(d_ref_gens) != 1
        Memento.error(_LOGGER, "Distribution network data must have 1 generator connected to ref bus, but $(length(d_ref_gens)) are present.")
    end
    d_gen = parse(Int, first(d_ref_gens))
    
    # Get its pmin and pmax
    pmin = d_data["gen"]["$d_gen"]["pmin"]
    pmax = d_data["gen"]["$d_gen"]["pmax"]
    
    ## Operations in transmission data

    # Check that t_bus exists
    if !haskey(t_data["bus"], "$t_bus")
        Memento.error(_LOGGER, "Bus $t_bus does not exist in transmission network data.")
    end

    # Add a generator connected to t_bus, to model the distribution network
    t_gen = length(t_data["gen"]) + 1 # Assumes that gens have contiguous indices starting from 1, as should be
    t_data["gen"]["$t_gen"] = Dict{String,Any}(
        "gen_bus"    => t_bus,
        "index"      => t_gen,
        "mbase"      => t_data["baseMVA"],
        "pmin"       => pmin,
        "pmax"       => pmax,
        "gen_status" => 1,
        "model"      => 2, # Cost model (2 => polynomial cost)
        "ncost"      => 1, # Number of cost coefficients (1 => polynomial of order 0)
        "cost"       => [0.0]
    )

    ## Operations in distribution data

    # Store the id of the generators, to later build the coupling constraint
    d_data["t_coupling_gen"] = t_gen
    d_data["d_coupling_gen"] = d_gen

    # Store the id of the physical distribution network
    d_data["sub_nw"] = sub_nw

end

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
            t_gen = _PM.ref(d_pm, d_nw, :t_coupling_gen) # Note: t_coupling_gen is defined in dist nw
            d_gen = _PM.ref(d_pm, d_nw, :d_coupling_gen)
            t_mbase = _PM.ref(t_pm, t_nw, :gen, t_gen, "mbase")
            d_mbase = _PM.ref(d_pm, d_nw, :gen, d_gen, "mbase")

            constraint_td_coupling(t_pm, d_pm, t_nw, d_nw, t_gen, d_gen, t_mbase, d_mbase)
        end
    end

end

"""
State the active power conservation between a distribution nw and the corresponding transmission nw.
"""
function constraint_td_coupling(t_pm::_PM.AbstractActivePowerModel, d_pm::_PM.AbstractBFModel, t_nw::Int, d_nw::Int, t_gen::Int, d_gen::Int, t_mbase::Float64, d_mbase::Float64)
    t_p_in = _PM.var(t_pm, t_nw, :pg, t_gen)
    d_p_in = _PM.var(d_pm, d_nw, :pg, d_gen)
    JuMP.@constraint(t_pm.model, t_mbase*t_p_in + d_mbase*d_p_in == 0.0) # t_pm.model == d_pm.model
end
