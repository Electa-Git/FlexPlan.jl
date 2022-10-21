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

    target_distribution = Vector{typeof(target_transmission)}(undef,length(source_distribution))
    Threads.@threads for i in eachindex(target_distribution)
        target_distribution[i] = convert_JSON(source_distribution[i]; kwargs...)
        target_distribution[i]["t_bus"] = find_t_bus(source_distribution[i], target_transmission)
    end

    return target_transmission, target_distribution
end

function find_t_bus(source_distribution, target_transmission)
    dist_id = source_distribution["genericParameters"]["thisDistributionNetwork"]
    pcc_bus_name = source_distribution["genericParameters"]["allDistributionNetworks"][dist_id]
    pcc_bus_id = findfirst(b->last(b["source_id"])==pcc_bus_name, target_transmission["nw"]["1"]["bus"])
    return parse(Int,pcc_bus_id)
end

function split_td(source::AbstractDict)

    transmission_task = Threads.@spawn extract_transmission(source)

    distribution = Vector{Dict{String,Any}}(undef, length(source["genericParameters"]["allDistributionNetworks"]))
    dist_info = collect(source["genericParameters"]["allDistributionNetworks"])
    Threads.@threads for i in eachindex(dist_info)
        dist_id, pcc_bus_id = dist_info[i]
        distribution[i] = extract_distribution(source, dist_id, pcc_bus_id)
    end

    transmission = fetch(transmission_task)

    return transmission, distribution
end

function extract_transmission(source::AbstractDict)

    transmission = Dict{String,Any}()
    transmission["genericParameters"] = source["genericParameters"]
    transmission["gridModelInputFile"] = Dict{String,Any}()
    transmission["scenarioDataInputFile"] = Dict{String,Any}()
    if haskey(source, "candidatesInputFile")
        transmission["candidatesInputFile"] = Dict{String,Any}()
    end

    # Transmission components
    for comp in ["dcBuses", "dcBranches", "converters", "psts"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = source["gridModelInputFile"][comp]
        end
        if haskey(source, "candidatesInputFile") && haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = source["candidatesInputFile"][comp]
        end
    end

    # T&D components having `isTransmission` key
    for comp in ["acBuses", "acBranches", "transformers"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = filter(device -> device["isTransmission"], source["gridModelInputFile"][comp])
        end
        if haskey(source, "candidatesInputFile") && haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["isTransmission"], source["candidatesInputFile"][comp])
        end
    end

    # T&D components not having `isTransmission` key
    transmission_acBuses = Set(bus["id"] for bus in transmission["gridModelInputFile"]["acBuses"])
    for comp in ["storage", "generators", "loads", "flexibleLoads"]
        if haskey(source["gridModelInputFile"], comp)
            transmission["gridModelInputFile"][comp] = filter(device -> device["acBusConnected"]∈transmission_acBuses, source["gridModelInputFile"][comp])
        end
        if haskey(source, "candidatesInputFile") && haskey(source["candidatesInputFile"], comp)
            transmission["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["acBusConnected"]∈transmission_acBuses, source["candidatesInputFile"][comp])
        end
        if haskey(source["scenarioDataInputFile"], comp)
            transmission_comp = Set(c["id"] for c in transmission["gridModelInputFile"][comp])
            transmission["scenarioDataInputFile"][comp] = filter(device -> device["id"]∈transmission_comp, source["scenarioDataInputFile"][comp])
        end
    end

    return transmission
end

function extract_distribution(source::AbstractDict, dist_id, pcc_bus_id)

    dist = Dict{String,Any}()
    dist["genericParameters"] = copy(source["genericParameters"])
    dist["genericParameters"]["thisDistributionNetwork"] = dist_id # Not in API, but useful.
    dist["gridModelInputFile"] = Dict{String,Any}()
    dist["scenarioDataInputFile"] = Dict{String,Any}()
    if haskey(source, "candidatesInputFile")
        dist["candidatesInputFile"] = Dict{String,Any}()
    end

    # Transmission components
    for comp in ["dcBuses", "dcBranches", "converters", "psts"]
        dist["gridModelInputFile"][comp] = Vector{Dict{String,Any}}()
        if haskey(source, "candidatesInputFile")
            dist["candidatesInputFile"][comp] = Vector{Dict{String,Any}}()
        end
    end

    # T&D components having `isTransmission` key
    for comp in ["acBuses", "acBranches", "transformers"]
        if haskey(source["gridModelInputFile"], comp)
            dist["gridModelInputFile"][comp] = filter(device -> !device["isTransmission"]&&device["distributionNetworkId"]==dist_id, source["gridModelInputFile"][comp])
        end
        if haskey(source, "candidatesInputFile") && haskey(source["candidatesInputFile"], comp)
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
        if haskey(source, "candidatesInputFile") && haskey(source["candidatesInputFile"], comp)
            dist["candidatesInputFile"][comp] = filter(cand -> cand[cand_name_from_dict(comp)]["acBusConnected"]∈dist_acBuses, source["candidatesInputFile"][comp])
        end
        if haskey(source["scenarioDataInputFile"], comp)
            dist_comp = Set(c["id"] for c in dist["gridModelInputFile"][comp])
            dist["scenarioDataInputFile"][comp] = filter(device -> device["id"]∈dist_comp, source["scenarioDataInputFile"][comp])
        end
    end

    # Add reference bus
    pos = findfirst(bus -> bus["id"]==pcc_bus_id, source["gridModelInputFile"]["acBuses"])
    pcc_bus = copy(source["gridModelInputFile"]["acBuses"][pos]) # Original in transmission must not be modified
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

    return dist
end