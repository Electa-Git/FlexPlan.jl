# Time series having length == number_of_hours * number_of_scenarios
function make_time_series(source::AbstractDict, lookup::AbstractDict, y::Int, sn_data::AbstractDict; number_of_hours::Int, number_of_scenarios::Int, scale_load::Real)
    target = Dict{String,Any}(
        "gen"        => Dict{String,Any}(),
        "load"       => Dict{String,Any}(),
        "storage"    => Dict{String,Any}(),
        "ne_storage" => Dict{String,Any}(),
    )

    for comp in source["scenarioDataInputFile"]["generators"]
        index = lookup["generators"][comp["id"]]
        if haskey(comp, "capacityFactor")
            p = ts_vector(comp, "capacityFactor", y; number_of_hours, number_of_scenarios) .* sn_data["gen"]["$index"]["pmax"]
            target["gen"]["$index"] = Dict{String,Any}("pmax" => p)
        end
    end

    for comp in source["scenarioDataInputFile"]["loads"]
        index = lookup["loads"][comp["id"]]
        pd    = ts_vector(comp, "demandReference", y; number_of_hours, number_of_scenarios)
        target["load"]["$index"] = Dict{String,Any}("pd" => scale_load*pd)
    end

    for comp in source["scenarioDataInputFile"]["storage"]
        index = lookup["storage"][comp["id"]]
        target["storage"]["$index"] = Dict{String,Any}()
        if haskey(comp, "powerExternalProcess")
            p = ts_vector(comp, "powerExternalProcess", y; number_of_hours, number_of_scenarios)
            target["storage"]["$index"]["stationary_energy_inflow"] = max.(p,0.0)
            target["storage"]["$index"]["stationary_energy_outflow"] = -min.(p,0.0)
        else
            target["storage"]["$index"]["stationary_energy_inflow"] = zeros(number_of_hours*number_of_scenarios)
            target["storage"]["$index"]["stationary_energy_outflow"] = zeros(number_of_hours*number_of_scenarios)
        end
        if haskey(comp, "maxAbsActivePower")
            target["storage"]["$index"]["charge_rating"] = ts_vector(comp, "maxAbsActivePower", y; number_of_hours, number_of_scenarios) * sn_data["storage"]["$index"]["charge_rating"]
        end
        if haskey(comp, "maxInjActivePower")
            target["storage"]["$index"]["discharge_rating"] = ts_vector(comp, "maxInjActivePower", y; number_of_hours, number_of_scenarios) * sn_data["storage"]["$index"]["discharge_rating"]
        end
    end

    if haskey(source, "candidatesInputFile")
        for cand in source["candidatesInputFile"]["storage"]
            comp = cand["storageData"]
            index = lookup["cand_storage"][comp["id"]]
            target["ne_storage"]["$index"] = Dict{String,Any}()
            if haskey(comp, "powerExternalProcess")
                p = ts_vector(comp, "powerExternalProcess", y; number_of_hours, number_of_scenarios)
                target["ne_storage"]["$index"]["stationary_energy_inflow"] = max.(p,0.0)
                target["ne_storage"]["$index"]["stationary_energy_outflow"] = -min.(p,0.0)
            else
                target["ne_storage"]["$index"]["stationary_energy_inflow"] = zeros(number_of_hours*number_of_scenarios)
                target["ne_storage"]["$index"]["stationary_energy_outflow"] = zeros(number_of_hours*number_of_scenarios)
            end
            if haskey(comp, "maxAbsActivePower")
                target["ne_storage"]["$index"]["charge_rating"] = ts_vector(comp, "maxAbsActivePower", y; number_of_hours, number_of_scenarios) * sn_data["ne_storage"]["$index"]["charge_rating"]
            end
            if haskey(comp, "maxInjActivePower")
                target["ne_storage"]["$index"]["discharge_rating"] = ts_vector(comp, "maxInjActivePower", y; number_of_hours, number_of_scenarios) * sn_data["ne_storage"]["$index"]["discharge_rating"]
            end
        end
    end

    return target
end

# Time series data vector from JSON component dict
function ts_vector(comp::AbstractDict, key::String, y::Int; number_of_hours::Int, number_of_scenarios::Int)
    # `comp[key]` is a Vector{Vector{Vector{Any}}} containing data of each scenario, year and hour
    # Returned value is a Vector{Float64} containing data of year y and each scenario and hour
    return mapreduce(Vector{Float64}, vcat, comp[key][s][y][1:number_of_hours] for s in 1:number_of_scenarios)
end
