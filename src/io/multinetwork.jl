"""
    make_multinetwork(sn_data, time_series; global_keys, number_of_nws, nw_id_offset)

Generate a multinetwork data structure from a single network and a time series.

# Arguments
- `sn_data`: single-network data structure to be replicated.
- `time_series`: data structure containing the time series.
- `global_keys`: keys that are stored once per multinetwork (they are not repeated in each
  `nw`).
- `number_of_nws`: number of networks to be created from `sn_data` and `time_series`;
  default: read from `dim`.
- `nw_id_offset`: optional value to be added to `time_series` ids to shift `nw` ids in
  multinetwork data structure; default: read from `dim`.
"""
function make_multinetwork(
        sn_data::Dict{String,Any},
        time_series::Dict{String,Any};
        global_keys = ["dim","multinetwork","name","per_unit","source_type","source_version"],
        number_of_nws::Int = length(sn_data["dim"][:li]),
        nw_id_offset::Int = sn_data["dim"][:offset]
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
        sn_data::Dict{String,Any};
        global_keys = ["dim","name","per_unit","source_type","source_version"],
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
    import_nws!(mn_data, others...)

Import into `mn_data["nw"]` the `nw`s contained in `others`.

`nw` ids of the two multinetworks must be contiguous (an error is raised otherwise).

See also: `merge_multinetworks!`.
"""
function import_nws!(mn_data::Dict{String,Any}, others::Dict{String,Any}...)
    if !_IM.ismultinetwork(mn_data)
        Memento.error(_LOGGER, "`import_nws!` can only be applied to multinetwork data dictionaries.")
    end
    for other in others
        if !isempty(keys(mn_data["nw"]) ∩ keys(other["nw"]))
            Memento.error(_LOGGER, "Attempting to import multinetworks having overlapping `nw` ids.")
        end
        merge!(mn_data["nw"], other["nw"])
    end
    first_id, last_id = extrema(parse.(Int,keys(mn_data["nw"])))
    if length(mn_data["nw"]) != last_id - first_id + 1
        Memento.error(_LOGGER, "The ids of the imported `nw`s must be contiguous.")
    end
    return mn_data
end

"""
    merge_multinetworks!(mn_data_1, mn_data_2, dimension)

Merge `mn_data_2` into `mn_data_1` along `dimension`.

`nw` ids of the two multinetworks must be contiguous (an error is raised otherwise).
Fields present in `mn_data_1` but not in `mn_data_2` are shallow-copied into `mn_data_1`.
Fields present in both multinetworks must be equal, except for `dim`, `nw` and possibly for
`name`.

See also: `import_nws!`.
"""
function merge_multinetworks!(mn_data_1::Dict{String,Any}, mn_data_2::Dict{String,Any}, dimension::Symbol)
    for k in ("dim", "nw")
        for data in (mn_data_1, mn_data_2)
            if k ∉ keys(data)
                Memento.error(_LOGGER, "Missing field $k from input data dictionary.")
            end
        end
    end

    mn_data_1["dim"] = merge_dim!(mn_data_1["dim"], mn_data_2["dim"], dimension)

    import_nws!(mn_data_1, mn_data_2)

    keys1 = setdiff(keys(mn_data_1), ("dim", "nw"))
    keys2 = setdiff(keys(mn_data_1), ("dim", "nw"))
    for k in keys1 ∩ keys2
        if mn_data_1[k] == mn_data_2[k]
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

"""
    slice = slice_multinetwork(data::Dict{String,Any}; kwargs...)

Slice a multinetwork keeping the networks that have the coordinates specified by `kwargs`.

`kwargs` must be of the form `name = <value>`, where `name` is the name of a dimension of
`dim` and `<value>` is an `Int` coordinate of that dimension.

Return a sliced multinetwork that shares its data with `data`.
The coordinates of the dimensions at which the original multinetwork is sliced are
accessible with `dim_meta(slice, <name>, "orig_id")` where `<name>` is the name of one of
those dimensions.
Forward and backward lookup dicts containing the network ids of `data` and `slice` are
accessible with `slice["slice"]["slice_orig_nw_lookup"]` and
`slice["slice"]["orig_slice_nw_lookup"]`.
"""
function slice_multinetwork(data::Dict{String,Any}; kwargs...)
    slice = Dict{String,Any}()
    for k in setdiff(keys(data), ("dim", "nw"))
        slice[k] = data[k]
    end
    dim, ids = slice_dim(data["dim"]; kwargs...)
    slice["dim"] = dim
    slice["nw"] = Dict{String,Any}()
    for (new_id, old_id) in enumerate(ids)
        slice["nw"]["$new_id"] = data["nw"]["$old_id"]
    end
    slice["slice"] = Dict{String,Any}()
    slice["slice"]["slice_orig_nw_lookup"] = Dict(enumerate(ids))
    slice["slice"]["orig_slice_nw_lookup"] = Dict((o,s) for (s,o) in slice["slice"]["slice_orig_nw_lookup"])
    return slice
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
    get!(mn_data, "name", "multinetwork")
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
