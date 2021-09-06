"""
    make_multinetwork(sn_data, time_series; global_keys, number_of_nws, nw_id_offset)

Generate a multinetwork data structure from a single network and a time series.

# Arguments
- `sn_data`: single-network data structure to be replicated.
- `time_series`: data structure containing the time series.
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each
  `nw`).
- `number_of_nws`: number of networks to be created.
- `nw_id_offset`: optional value to be added to `time_series` ids to shift `nw` ids in
  multinetwork data structure.
"""
function make_multinetwork(
        sn_data::Dict{String,Any},
        time_series::Dict{String,Any};
        global_keys = ["dim","multinetwork","name","per_unit","source_type","source_version"],
        number_of_nws::Int = length(sn_data["dim"][:li]),
        nw_id_offset::Int = 0
    )

    if _IM.ismultinetwork(sn_data)
        Memento.error(_LOGGER, "`sn_data` argument must be a single network.")
    end
    if !haskey(sn_data, "dim")
        Memento.error(_LOGGER, "Missing `dim` dict in `sn_data` argument. The function `add_dimension!` must be called before `make_multinetwork`.")
    end

    mn_data = Dict{String,Any}("nw"=>Dict{String,Any}())
    _add_mn_global_values!(mn_data, sn_data, global_keys)
    _add_time_series!(mn_data, sn_data, global_keys, time_series, number_of_nws, nw_id_offset)

    return mn_data
end

"""
    make_multinetwork(sn_data; global_keys)

Generate a multinetwork data structure - having only one `nw` - from a single network.

# Arguments
- `sn_data`: single-network data structure to be replicated.
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each
  `nw`).
"""
function make_multinetwork(
        sn_data::Dict{String,Any},
        global_keys = ["dim","source_type","source_version","per_unit"],
    )

    if _IM.ismultinetwork(sn_data)
        Memento.error(_LOGGER, "`sn_data` argument must be a single network.")
    end
    if !haskey(sn_data, "dim")
        Memento.error(_LOGGER, "Missing `dim` dict in `sn_data` argument. The function `add_dimension!` must be called before `make_multinetwork`.")
    end

    mn_data = Dict{String,Any}("nw"=>Dict{String,Any}())
    _add_mn_global_values!(mn_data, sn_data, global_keys)
    template_nw = _make_template_nw(sn_data, global_keys)
    mn_data["nw"]["1"] = copy(template_nw)

    return mn_data
end

"""
    extend_multinetwork!(mn_data, sn_data, time_series; global_keys, number_of_nws, nw_id_offset)

Generate a multinetwork data structure from `sn_data` and `time_series` and merge into `mn_data`.

# Arguments
- `mn_data`: the multinetwork data structure to be extended.
- `sn_data`: single-network data structure to be replicated.
- `time_series`: data structure containing the timeseries.
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each
  `nw`).
- `number_of_nws`: number of networks to be created from `sn_data` and `time_series`.
- `nw_id_offset`: optional value to be added to `time_series` ids to shift `nw` ids in
  multinetwork data structure; the maximum nw idx in `mn_data` is adopted as default value.
"""
function extend_multinetwork!(
        mn_data::Dict{String,Any},
        sn_data::Dict{String,Any},
        time_series::Dict{String,Any};
        global_keys = ["dim","multinetwork","name","per_unit","source_type","source_version"],
        number_of_nws::Int = length(sn_data["dim"][:li]),
        nw_id_offset::Int = last(mn_data["dim"][:li])
    )
    mn_data_2 = make_multinetwork(sn_data, time_series; global_keys, number_of_nws, nw_id_offset)
    mn_data = merge_multinetworks!(mn_data, mn_data_2)
end

"""
    merge_multinetworks!(mn_data_1, mn_data_2)

Merge `mn_data_2` into `mn_data_1`.

`nw` ids of the two multinetworks must not overlap (an error is raised otherwise).
Fields present in `mn_data_1` but not in `mn_data_2` are copied into `mn_data_1`.
Fields present in both multinetworks must be equal, except for `nw` and possibly for `name`.
"""
function merge_multinetworks!(mn_data_1::Dict{String,Any}, mn_data_2::Dict{String,Any})
    keys1 = keys(mn_data_1)
    keys2 = keys(mn_data_2)
    for k in keys1 ∩ keys2
        if k == "nw"
            if !isempty(keys(mn_data_1["nw"]) ∩ keys(mn_data_2["nw"]))
                Memento.error(_LOGGER, "Attempting to merge multinetworks having overlapping `nw` ids.")
            end
            mn_data_1["nw"] = merge(mn_data_1["nw"], mn_data_2["nw"])
        elseif mn_data_1[k] == mn_data_2[k]
            continue
        elseif k == "name" # Applied only if names are different
            mn_data_1["name"] = "Merged multinetwork"
        else
            Memento.error(_LOGGER, "Attempting to merge multinetworks that differ on the value of \"$k\".")
        end
    end
    for k in setdiff(keys2, keys1)
        mn_data_1[k] = mn_data_2[k]
    end
    return mn_data_1
end

# Copy global values from sn_data to mn_data handling special cases
function _add_mn_global_values!(mn_data, sn_data, global_keys)

    # Insert global values into mn_data by copying from sn_data
    for k in global_keys
        if haskey(sn_data, k)
            mn_data[k] = sn_data[k]
        end
    end

    # Special cases are handled below

    mn_data["multinetwork"] = true

    if haskey(mn_data, "name")
        mn_data["name"] *= ", " * get(sn_data, "name", "anonymous")
    else
        mn_data["name"] = "Multinetwork based on: " * get(sn_data, "name", "anonymous")
    end

    # If the multinetwork is intended to store data belonging to different physical networks, add or update sub_nw lookup dict
    if haskey(sn_data, "td_coupling")
        count = length(sn_data["dim"][:li]) # Number of networks to be created
        sub_nw = sn_data["td_coupling"]["sub_nw"]
        if !haskey(mn_data, "sub_nw")
            mn_data["sub_nw"] = Dict{String,Set{Int}}()
        end
        if haskey(mn_data["sub_nw"], sub_nw)
            Memento.error(_LOGGER, "Subnetwork $sub_nw already exists in multinetwork data.")
        end
        mn_data["sub_nw"]["$sub_nw"] = Set{Int}()
        for idx in 1:count
            push!(mn_data["sub_nw"]["$sub_nw"], idx + nw_id_offset) # Add nw idx to sub_nw lookup dict
        end
    end
end

# Make a deep copy of `data` and remove global keys
function _make_template_nw(sn_data, global_keys)
    template_nw = deepcopy(sn_data)
    for k in global_keys
        delete!(template_nw, k)
    end
    return template_nw
end

# Build multinetwork data structure: for each network, replicate the template and replace with data from time_series
function _add_time_series!(mn_data, sn_data, global_keys, time_series, number_of_nws, offset)
    template_nw = _make_template_nw(sn_data, global_keys)
    for time_series_idx in 1:number_of_nws
        n = time_series_idx + offset
        mn_data["nw"]["$n"] = _build_nw(template_nw, time_series, time_series_idx)
    end
end

# Build the nw by shallow-copying the template and substituting data from time_series only if is different.
function _build_nw(template_nw, time_series, idx)
    nw = copy(template_nw)
    for (key, element) in time_series
        if haskey(nw, key)
            nw[key] = copy(template_nw[key])
            for (l, element) in time_series[key]
                if haskey(nw[key], l)
                    nw[key][l] = deepcopy(template_nw[key][l])
                    for (m, property) in time_series[key][l]
                        if haskey(nw[key][l], m)
                            nw[key][l][m] = property[idx]
                        else
                            Memento.warn(_LOGGER, "Property $m for $key $l not found, will be ignored.")
                        end
                    end
                else
                    Memento.warn(_LOGGER, "Key $l not found, will be ignored.")
                end
            end
        else
            Memento.warn(_LOGGER, "Key $key not found, will be ignored.")
        end
    end
    return nw
end
