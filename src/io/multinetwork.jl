"""
Generate a multinetwork data structure

- `sn_data`: single-network data structure to be replicated
- `extradata`: data structure containing the timeseries 
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each `nw`)
- `nw_id_offset`: value to be added to extradata ids to shift `nw` ids in multinetwork data structure
"""
function multinetwork_data(sn_data::Dict{String,Any}, extradata::Dict{String,Any}, global_keys::Set{String}; nw_id_offset::Int=0)
    
    if InfrastructureModels.ismultinetwork(sn_data)
        Memento.error(_LOGGER, "replicate can only be used on single networks")
    end

    count = extradata["dim"] # Number of networks to be created

    mn_data = Dict{String,Any}(
        "nw" => Dict{String,Any}()
    )

    template_nw = deepcopy(sn_data)

    # Move global keys from template_nw to mn_data, so they will not be repeated in each nw
    for k in global_keys
        if haskey(template_nw, k)
            mn_data[k] = template_nw[k]
            delete!(template_nw, k)
        end
    end

    mn_data["multinetwork"] = true
    mn_data["name"] = "$count replicates of " * get(sn_data, "name", "anonymous")

    # Build multinetwork data structure: for each network, replicate the template and replace with data from extradata
    for extradata_idx in 1:count
        n = extradata_idx + nw_id_offset
        mn_data["nw"]["$n"] = copy(template_nw)
        for (key, element) in extradata
            if key == "dim"
            else
                if haskey(mn_data["nw"]["$n"], key)
                    mn_data["nw"]["$n"][key] = copy(template_nw[key])
                    for (l, element) in extradata[key]
                        if haskey(mn_data["nw"]["$n"][key], l)
                            mn_data["nw"]["$n"][key][l] = deepcopy(template_nw[key][l])
                            for (m, property) in extradata[key][l]
                                if haskey(mn_data["nw"]["$n"][key][l], m)
                                    mn_data["nw"]["$n"][key][l][m] = property[extradata_idx]
                                else
                                    Memento.warn(_LOGGER, ["Property ", m, " for ", key, " ", l, " not found, will be ignored"])
                                end
                            end
                        else
                            Memento.warn(_LOGGER, [key, " ", l, " not found, will be ignored"])
                        end
                    end
                else
                    Memento.warn(_LOGGER, ["Key ", key, " not found, will be ignored"])
                end
            end
        end
    end

    return mn_data
end
