"""
    parse_file(file; <keyword arguments>)

Parse a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a FlexPlan data structure,
including DC components, storage and flexible loads.

Mandatory tables: `bus`, `gen`, `branch`, `load_extra`.
Optional tables: `gencost`, `branch_oltc`, `storage`, `storage_extra`, `ne_storage`.
Other tables can be added as well: they will be made avaiable in the returned object.

Keyword arguments, if any, are forwarded to `PowerModels.parse_file()`.
"""
function parse_file(file::String; kwargs...)
    data = _PM.parse_file(file; kwargs...)
    if !haskey(data, "ne_branch")
        data["ne_branch"] = Dict{String,Any}()
    end
    if haskey(data, "busdc")
        _PMACDC.process_additional_data!(data)
    end
    add_storage_data!(data)
    if haskey(data, "load_extra")
        add_flexible_demand_data!(data)
    else
        Memento.error(_LOGGER, "no load_extra table found in input file.")
    end
    return data
end

"""
    parse_file(file, scenario; scale_cost=1.0, <keyword arguments>)

Also scale cost data according to `scenario` by using `scale_cost_data!()`.
Additionally, pass `scale_cost` to `scale_cost_data!()` as `factor`.

# See also

[`scale_cost_data!`](@ref)
"""
function parse_file(file::String, scenario::Dict{String,Any}; scale_cost = 1.0, kwargs...)
    data = parse_file(file; kwargs...)
    scale_cost_data!(data, scenario; factor = scale_cost)
    return data
end
