const dict_candidate_lookup = Dict{String,String}(
    "acBuses"       => "acBus",
    "dcBuses"       => "dcBus",
    "acBranches"    => "acBranch",
    "dcBranches"    => "dcBranch",
    "converters"    => "converter",
    "transformers"  => "acBranch",
    "storage"       => "storage",
    "generators"    => "generator",
    "flexibleLoads" => "load",
    "psts"          => "pst",
)

function cand_name_from_dict(dict::String)
    dict_candidate_lookup[dict]
end

"""
    convert_JSON(file; <keyword arguments>)
    convert_JSON(dict; <keyword arguments>)

Convert a JSON `file` or a `dict` conforming to the FlexPlan WP3 API into a FlexPlan.jl dict.

# Arguments
- `oltc::Bool=true`: in distribution networks, whether to add OLTCs with ±10% voltage
  regulation to existing and candidate transformers.
- `scale_gen::Real=1.0`: scale factor of all generators.
- `scale_load::Real=1.0`: scale factor of loads.
- `number_of_hours::Union{Int,Nothing}=nothing`: parse only the first hours of the
  file/dict.
- `number_of_scenarios::Union{Int,Nothing}=nothing`: parse only the first scenarios of the
  file/dict.
- `number_of_years::Union{Int,Nothing}=nothing`: parse only the first years of the
  file/dict.
- `cost_scale_factor::Real=1.0`: scale factor for all costs.
- `year_scale_factor::Union{Real,Nothing}=nothing`: how many years a representative year
  should represent (default: read from JSON).
- `init_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  target dict after its initialization. They must have exactly one argument (the target
  dict) and can modify it; the return value is unused.
- `sn_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  single-network dictionaries containing data for each single year, just before
  `_FP.scale_data!` is called. They must have exactly one argument (the single-network dict)
  and can modify it; the return value is unused.
- `share_data::Bool=true`: whether constant data is shared across networks (faster) or
  duplicated (uses more memory, but ensures networks are independent; useful if further
  transformations will be applied).

# Extended help
Features of FlexPlan WP3 API not supported in FlexPlan.jl:
- scenario probabilities depending on year (only constant probabilities are allowed);
- number of hours depending on scenario (all scenarios must have the same number of hours);
- PSTs;
- `gridModelInputFile.converters.ratedActivePowerDC`;
- `gridModelInputFile.storage.minEnergy`;
- `gridModelInputFile.storage.maxAbsRamp`;
- `gridModelInputFile.storage.maxInjRamp`;
- uniqueness of candidate components (each candidate can be reinvested at the end of its
  lifetime).
"""
function convert_JSON end

function convert_JSON(file::String; kwargs...)
    source_dict = JSON.parsefile(file)
    convert_JSON(source_dict; kwargs...)
end

function convert_JSON(source::AbstractDict;
        oltc::Bool = true,
        scale_gen::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Union{Int,Nothing} = nothing,
        number_of_scenarios::Union{Int,Nothing} = nothing,
        number_of_years::Union{Int,Nothing} = nothing,
        cost_scale_factor::Real = 1.0,
        year_scale_factor::Union{Real,Nothing} = nothing,
        init_data_extensions::Vector{<:Function} = Function[],
        sn_data_extensions::Vector{<:Function} = Function[],
        share_data::Bool = true,
    )

    # Define target dict

    target = Dict{String, Any}(
        "nw"           => Dict{String,Any}(),
        "multinetwork" => true,
        "per_unit"     => true,
    )

    # Add dimensions

    if length(unique(vcat(source["genericParameters"]["nbHours"]...))) > 1
        Memento.error(_LOGGER, "All scenarios must have the same number of hours.") # Dimensions are implemented as a multidimensional array, so the length of one dimension cannot depend on the id along another dimension.
    end
    if isnothing(number_of_hours)
        number_of_hours = first(first(source["genericParameters"]["nbHours"]))
    elseif number_of_hours > first(first(source["genericParameters"]["nbHours"]))
        Memento.error(_LOGGER, "$number_of_hours hours requested, but only " * string(first(first(source["genericParameters"]["nbHours"]))) * " found in input dict.")
    end
    _FP.add_dimension!(target, :hour, number_of_hours)

    if isnothing(number_of_scenarios)
        number_of_scenarios = source["genericParameters"]["nbScenarios"]
    elseif number_of_scenarios > source["genericParameters"]["nbScenarios"]
        Memento.error(_LOGGER, "$number_of_scenarios scenarios requested, but only " * string(source["genericParameters"]["nbScenarios"]) * " found in input dict.")
    end
    if haskey(source["genericParameters"], "scenarioProbabilities")
        if maximum(length.(unique.(source["genericParameters"]["scenarioProbabilities"]))) > 1
            Memento.warn(_LOGGER, "Only constant probabilities are supported for scenearios. Using first year probabilities for every year.")
        end
        scenario_probabilities = first(first.(source["genericParameters"]["scenarioProbabilities"]), number_of_scenarios) # The outermost `first` is needed if the user has specified a number of scenarios lower than that available.
    else
        scenario_probabilities = fill(1/number_of_scenarios,number_of_scenarios)
    end
    scenario_properties = Dict(id => Dict{String,Any}("probability"=>prob) for (id,prob) in enumerate(scenario_probabilities))
    _FP.add_dimension!(target, :scenario, scenario_properties)

    if isnothing(number_of_years)
        number_of_years = length(source["genericParameters"]["years"])
    elseif number_of_years > length(source["genericParameters"]["years"])
        Memento.error(_LOGGER, "$number_of_years years requested, but only " * string(length(source["genericParameters"]["years"])) * " found in input dict.")
    end
    if isnothing(year_scale_factor)
        if haskey(source["genericParameters"], "nbRepresentedYears")
            year_scale_factor = source["genericParameters"]["nbRepresentedYears"]
        else
            Memento.error(_LOGGER, "At least one of JSON attribute `genericParameters.nbRepresentedYears` and function keyword argument `year_scale_factor` must be specified.")
        end
    end
    _FP.add_dimension!(target, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))

    # Generate ID lookup dict

    lookup_acBranches = id_lookup(source["gridModelInputFile"]["acBranches"])
    lookup = Dict(
        "acBuses"           => id_lookup(source["gridModelInputFile"]["acBuses"]),
        "acBranches"        => lookup_acBranches,
        "transformers"      => id_lookup(source["gridModelInputFile"]["transformers"]; offset=length(lookup_acBranches)), # AC branches are split between `acBranches` and `transformers` dicts in JSON files
        "generators"        => id_lookup(source["gridModelInputFile"]["generators"]),
        "loads"             => id_lookup(source["gridModelInputFile"]["loads"]),
        "storage"           => id_lookup(source["gridModelInputFile"]["storage"]),
        "dcBuses"           => id_lookup(source["gridModelInputFile"]["dcBuses"]),
        "dcBranches"        => id_lookup(source["gridModelInputFile"]["dcBranches"]),
        "converters"        => id_lookup(source["gridModelInputFile"]["converters"]),
    )
    if haskey(source, "candidatesInputFile")
        lookup_cand_acBranches = id_lookup(source["candidatesInputFile"]["acBranches"], "acBranch")
        lookup["cand_acBranches"]   = lookup_cand_acBranches
        lookup["cand_transformers"] = id_lookup(source["candidatesInputFile"]["transformers"], "acBranch"; offset=length(lookup_cand_acBranches)) # AC branches are split between `acBranches` and `transformers` dicts in JSON files
        lookup["cand_storage"]      = id_lookup(source["candidatesInputFile"]["storage"], "storage")
        lookup["cand_dcBranches"]   = id_lookup(source["candidatesInputFile"]["dcBranches"], "dcBranch")
        lookup["cand_converters"]   = id_lookup(source["candidatesInputFile"]["converters"], "converter")
    end

    # Compute availability of candidates

    if haskey(source, "candidatesInputFile")
        year_scale_factor = _FP.dim_meta(target, :year, "scale_factor")
        year_lookup = Dict{Int,Int}((year,y) for (y,year) in enumerate(source["genericParameters"]["years"]))
        cand_availability = Dict{String,Any}(
            "acBranches"   => availability(source, "acBranches",    "acBranch",  year_lookup, year_scale_factor, number_of_years),
            "transformers" => availability(source, "transformers",  "acBranch",  year_lookup, year_scale_factor, number_of_years),
            "loads"        => availability(source, "flexibleLoads", "load",      year_lookup, year_scale_factor, number_of_years),
            "storage"      => availability(source, "storage",       "storage",   year_lookup, year_scale_factor, number_of_years),
            "dcBranches"   => availability(source, "dcBranches",    "dcBranch",  year_lookup, year_scale_factor, number_of_years),
            "converters"   => availability(source, "converters",    "converter", year_lookup, year_scale_factor, number_of_years),
        )
    end

    # Apply init data extensions

    for f! in init_data_extensions
        f!(target)
    end

    # Build data year by year

    for y in 1:number_of_years
        sn_data = haskey(source, "candidatesInputFile") ? nw(source, lookup, cand_availability, y; oltc, scale_gen) : nw(source, lookup, y; oltc, scale_gen)
        sn_data["dim"] = target["dim"]

        # Apply single network data extensions
        for f! in sn_data_extensions
            f!(sn_data)
        end

        _FP.scale_data!(sn_data; year_idx=y, cost_scale_factor)
        time_series = make_time_series(source, lookup, y, sn_data; number_of_hours, number_of_scenarios, scale_load)
        year_data = _FP.make_multinetwork(sn_data, time_series; number_of_nws=number_of_hours*number_of_scenarios, nw_id_offset=number_of_hours*number_of_scenarios*(y-1), share_data)
        add_singular_data!(year_data, source, lookup, y)
        _FP.import_nws!(target, year_data)
    end

    return target
end

# Define a bijective map from existing JSON String ids to FlexPlan Int ids (generated in _id_lookup)
function id_lookup(component_vector::Vector; offset::Int=0)
    json_ids = [d["id"] for d in component_vector]
    return _id_lookup(json_ids, offset)
end

function id_lookup(component_vector::Vector, sub_key::String; offset::Int=0)
    json_ids = [d[sub_key]["id"] for d in component_vector]
    return _id_lookup(json_ids, offset)
end

function _id_lookup(json_ids::Vector, offset::Int)
    sort!(json_ids) # Sorting prevents changes due to the order of elements in JSON files
    int_ids = range(1+offset; length=length(json_ids))
    lookup = Dict{String,Int}(zip(json_ids, int_ids))
    if length(lookup) < length(json_ids)
        Memento.error(_LOGGER, "IDs must be unique (found only $(length(lookup)) unique IDs, should be $(length(json_ids))).")
    end
    return lookup
end

function availability(source::AbstractDict, comp_name::String, sub_key::String, year_lookup::AbstractDict, year_scale_factor::Int, number_of_years::Int)
    target = Dict{String,Vector{Bool}}()
    for comp in source["candidatesInputFile"][comp_name]
        id = comp[sub_key]["id"]
        investment_horizon = [year_lookup[year] for year in comp["horizons"]]
        if last(investment_horizon) - first(investment_horizon) ≥ length(investment_horizon)
            Memento.warn(_LOGGER, "Horizon of $comp_name $id is not a contiguous set.")
        end
        raw_lifetime = comp["lifetime"] ÷ year_scale_factor
        availability_horizon_start = first(investment_horizon)
        availability_horizon_end = min(last(investment_horizon)+raw_lifetime-1, number_of_years)
        target[id] = [availability_horizon_start ≤ y ≤ availability_horizon_end for y in 1:number_of_years]
    end
    return target
end

function split_td(source::AbstractDict)

    transmission = Dict{String,Any}()
    transmission["genericParameters"] = source["genericParameters"]
    transmission["gridModelInputFile"] = Dict{String,Any}()
    transmission["candidatesInputFile"] = Dict{String,Any}()
    transmission["scenarioDataInputFile"] = Dict{String,Any}()

    # Transmission components
    for comp in ["dcBuses", "dcBranches", "converters", "psts"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = source["gridModelInputFile"][comp]
        end
        if haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = source["candidatesInputFile"][comp]
        end
    end
    # T&D components having `isTransmission` key
    for comp in ["acBuses", "acBranches", "transformers"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = filter(device -> device["isTransmission"], source["gridModelInputFile"][comp])
        end
        if haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["isTransmission"], source["candidatesInputFile"][comp])
        end
    end
    # T&D components not having `isTransmission` key
    transmission_acBuses = Set(bus["id"] for bus in transmission["gridModelInputFile"]["acBuses"])
    for comp in ["storage", "generators", "loads", "flexibleLoads"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = filter(device -> device["acBusConnected"]∈transmission_acBuses, source["gridModelInputFile"][comp])
        end
        if haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["acBusConnected"]∈transmission_acBuses, source["candidatesInputFile"][comp])
        end
        if haskey(source["scenarioDataInputFile"], comp)
            transmission_comp = Set(c["id"] for c in transmission["gridModelInputFile"][comp])
            transmission["scenarioDataInputFile"][comp] = filter(device -> device["id"]∈transmission_comp, source["scenarioDataInputFile"][comp])
        end
    end

    distribution = Vector{Dict{String,Any}}()
    for (dist_id,pcc_bus_id) in source["genericParameters"]["allDistributionNetworks"]
        dist = Dict{String,Any}()
        dist["genericParameters"] = source["genericParameters"]
        dist["gridModelInputFile"] = Dict{String,Any}()
        dist["candidatesInputFile"] = Dict{String,Any}()
        dist["scenarioDataInputFile"] = Dict{String,Any}()
        # Transmission components
        for comp in ["dcBuses", "dcBranches", "converters", "psts"]
            dist["gridModelInputFile"][comp] = Vector{Dict{String,Any}}()
            dist["candidatesInputFile"][comp] = Vector{Dict{String,Any}}()
        end
        # T&D components having `isTransmission` key
        for comp in ["acBuses", "acBranches", "transformers"]
            if haskey(source["gridModelInputFile"], comp)
                dist["gridModelInputFile"][comp] = filter(device -> !device["isTransmission"]&&device["distributionNetworkId"]==dist_id, source["gridModelInputFile"][comp])
            end
            if haskey(source["candidatesInputFile"], comp)
                dist["candidatesInputFile"][comp] = filter(source["candidatesInputFile"][comp]) do cand
                    device = cand[cand_name_from_dict(comp)]
                    !device["isTransmission"] && device["distributionNetworkId"]==dist_id
                end
            end
        end
        # T&D components not having `isTransmission` key
        dist_acBuses = Set(bus["id"] for bus in dist["gridModelInputFile"]["acBuses"])
        for comp in ["storage", "generators", "loads", "flexibleLoads"]
            if haskey(source["gridModelInputFile"], comp)
                dist["gridModelInputFile"][comp] = filter(device -> device["acBusConnected"]∈dist_acBuses, source["gridModelInputFile"][comp])
            end
            if haskey(source["candidatesInputFile"], comp)
                dist["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["acBusConnected"]∈dist_acBuses, source["candidatesInputFile"][comp])
            end
            if haskey(source["scenarioDataInputFile"], comp)
                dist_comp = Set(c["id"] for c in dist["gridModelInputFile"][comp])
                dist["scenarioDataInputFile"][comp] = filter(device -> device["id"]∈dist_comp, source["scenarioDataInputFile"][comp])
            end
        end
        # Add reference bus
        pos = findfirst(bus -> bus["id"]==pcc_bus_id, transmission["gridModelInputFile"]["acBuses"])
        pcc_bus = copy(transmission["gridModelInputFile"]["acBuses"][pos]) # Original in transmission must not be modified
        pcc_bus["busType"] = 3 # Slack bus
        push!(dist["gridModelInputFile"]["acBuses"], pcc_bus)
        # Add reference generator
        pos = findfirst(transformer -> transformer["acBusOrigin"]==pcc_bus_id, dist["gridModelInputFile"]["transformers"])
        pcc_transformer = dist["gridModelInputFile"]["transformers"][pos]
        number_of_years = length(source["genericParameters"]["years"])
        estimated_cost = source["genericParameters"]["estimateCostTdExchange"]
        pcc_gen = Dict{String,Any}(
            "id"               => "PCC",
            "acBusConnected"   => pcc_bus["id"],
            "maxActivePower"   => pcc_transformer["ratedApparentPower"], # Will be limited by the transformer, no need for a tight bound here.
            "minActivePower"   => -pcc_transformer["ratedApparentPower"], # Will be limited by the transformer, no need for a tight bound here.
            "maxReactivePower" => pcc_transformer["ratedApparentPower"], # Will be limited by the transformer, no need for a tight bound here.
            "minReactivePower" => -pcc_transformer["ratedApparentPower"], # Will be limited by the transformer, no need for a tight bound here.
            "generationCosts"  => repeat([estimated_cost], number_of_years),
            "curtailmentCosts" => repeat([0.0], number_of_years)
        )
        push!(dist["gridModelInputFile"]["generators"], pcc_gen)

        push!(distribution, dist)
    end

    return transmission, distribution
end

"""
    convert_JSON_td(file; <keyword arguments>)
    convert_JSON_td(dict; <keyword arguments>)

Convert a JSON `file` or a `dict` conforming to the FlexPlan WP3 API and containing both transmission and distribution networks.

Output:
- one dict containing data related to the transmission network;
- one vector of dicts containing data related to distribution networks.

# Arguments
Refer to `convert_JSON` documentation.
"""
function convert_JSON_td end

function convert_JSON_td(file::String; kwargs...)
    source_dict = JSON.parsefile(file)
    convert_JSON_td(source_dict; kwargs...)
end

function convert_JSON_td(source::AbstractDict; kwargs...)
    source_transmission, source_distribution = split_td(source)
    target_transmission = convert_JSON(source_transmission; kwargs...)
    target_distribution = map(dist -> convert_JSON(dist; kwargs...), source_distribution)
    for (i,pcc_bus_name) in enumerate(values(source["genericParameters"]["allDistributionNetworks"]))
        pcc_bus_id = findfirst(b->last(b["source_id"])==pcc_bus_name, target_transmission["nw"]["1"]["bus"])
        target_distribution[i]["t_bus"] = parse(Int,pcc_bus_id)
    end
    return target_transmission, target_distribution
end
