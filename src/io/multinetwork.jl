"""
Generate a multinetwork data structure

- `sn_data`: single-network data structure to be replicated
- `extradata`: data structure containing the timeseries
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each `nw`)
- `merge_into`: an optional multinetwork data structure to merge into
- `nw_id_offset`: optional value to be added to extradata ids to shift `nw` ids in multinetwork data
  structure; if `merge_into` is used, then the maximum nw idx is adopted as default value
"""
function multinetwork_data(
        sn_data::Dict{String,Any},
        extradata::Dict{String,Any},
        global_keys::Set{String} = Set{String}(["source_type","scenario","scenario_prob","source_version","per_unit"]); # Not a kwarg for backward compatibility with previous syntax
        merge_into::Dict{String,Any} = Dict{String,Any}("nw"=>Dict{String,Any}()),
        nw_id_offset::Int = !haskey(merge_into, "sub_nw") ? 0 : max((max(nw_set...) for nw_set in values(merge_into["sub_nw"]))...)
    )

    if InfrastructureModels.ismultinetwork(sn_data)
        Memento.error(_LOGGER, "replicate can only be used on single networks")
    end

    count = extradata["dim"] # Number of networks to be created

    mn_data = merge_into # Just to rename

    template_nw = deepcopy(sn_data)

    # Move global keys from template_nw to mn_data, so they will not be repeated in each nw
    for k in global_keys
        if haskey(template_nw, k)
            mn_data[k] = template_nw[k]
            delete!(template_nw, k)
        end
    end

    mn_data["multinetwork"] = true
    delete!(template_nw, "multinetwork") # In case is not passed among global keys

    if haskey(mn_data, "name")
        mn_data["name"] *= ", " * get(sn_data, "name", "anonymous")
    else
        mn_data["name"] = "Multinetwork based on: " * get(sn_data, "name", "anonymous")
    end
    delete!(template_nw, "name") # In case is not passed among global keys

    # If the multinetwork is intended to store data belonging to different physical networks, add or update sub_nw lookup dict
    if haskey(sn_data, "td_coupling")
        sub_nw = sn_data["td_coupling"]["sub_nw"]
        if !haskey(mn_data, "sub_nw")
            mn_data["sub_nw"] = Dict{String,Set{Int}}()
        end
        if haskey(mn_data["sub_nw"], sub_nw)
            Memento.error(_LOGGER, "Subnetwork $sub_nw already exists in multinetwork data.")
        end
        mn_data["sub_nw"]["$sub_nw"] = Set{Int}()
    end

    # Build multinetwork data structure: for each network, replicate the template and replace with data from extradata
    for extradata_idx in 1:count
        n = extradata_idx + nw_id_offset
        if haskey(mn_data, "sub_nw")
            push!(mn_data["sub_nw"]["$sub_nw"], n) # Add nw idx to sub_nw lookup dict
        end
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

"""
    shift_sub_nw!(mn_data; <keyword arguments>)

Shift `sub_nw` and `nw` ids of a multinetwork data structure.

Keyword arguments `sub_nw_offset` and `nw_offset` can be used to specify the shift amounts. Their
default values are the minimal quantities that ensure that the ids do not overlap.
"""
function shift_sub_nw!(
        mn_data::Dict{String,Any};
        sub_nw_offset = max(parse.(Int,keys(mn_data["sub_nw"]))...) - min(parse.(Int,keys(mn_data["sub_nw"]))...) + 1,
        nw_offset = max(parse.(Int,keys(mn_data["nw"]))...) - min(parse.(Int,keys(mn_data["nw"]))...) + 1
    )
    sub_nws = mn_data["sub_nw"]
    nws = mn_data["nw"]

    for n in collect(keys(nws)) # collect is needed to iterate while deleting keys
        nws["$(parse(Int,n)+nw_offset)"] = pop!(nws, n)
    end

    for sn in collect(keys(sub_nws)) # collect is needed to iterate while deleting keys
        for n in collect(sub_nws[sn]) # collect is needed to iterate while deleting keys
            delete!(sub_nws[sn], n)
            push!(sub_nws[sn], n+nw_offset)
        end
        sub_nws["$(parse(Int,sn)+sub_nw_offset)"] = pop!(sub_nws, sn)
    end
    return (sub_nw_offset, nw_offset)
end

"""
    merge_multinetworks(mn_data_1, mn_data_2; copy = false)

Merge two multinetworks.

`nw` and `sub_nw` ids of the two multinetworks must not overlap (an error is raised otherwise).
Other fields must be equal, except possibly for `name`.

If `copy` is false (default), the merging operation is done in an efficient way by reusing most of
original multinetwork objects; otherwise, a deep copy is performed to assure independence
from the original multinetworks.
"""
function merge_multinetworks(mn_data_1::Dict{String,Any}, mn_data_2::Dict{String,Any}; copy::Bool = false)
    res = Dict{String,Any}()
    keys_1 = keys(mn_data_1)
    keys_2 = keys(mn_data_2)
    for k in keys_1 ∩ keys_2
        if k ∈ ("nw", "sub_nw")
            if isempty(keys(mn_data_1[k]) ∩ keys(mn_data_2[k]))
                res[k] = merge(mn_data_1[k], mn_data_2[k])
            else
                Memento.error(_LOGGER, "Attempting to merge multinetworks having overlapping $k ids.")
            end
        elseif mn_data_1[k] == mn_data_2[k]
            res[k] = mn_data_1[k]
        elseif k == "name"
            res[k] = "Merged multinetwork"
        else
            Memento.error(_LOGGER, "Attempting to merge multinetworks that differ on key \"$k\".")
        end
    end
    return copy ? deepcopy(res) : res
end
