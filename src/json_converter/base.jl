"""
    convert_JSON(file; <keyword arguments>)
    convert_JSON(dict; <keyword arguments>)

Convert a JSON `file` or a `dict` conforming to the FlexPlan WP3 API into a FlexPlan.jl dict.

Costs are scaled with the assumption that every representative year represents 10 years.

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
- combined transmission and distribution networks;
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
    year_scale_factor = 10 # Assumption: every representative year represents 10 years
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
