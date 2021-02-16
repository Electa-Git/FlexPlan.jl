"""
    parse_file(file; <keyword arguments>)

Parse a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a FlexPlan data structure,
including DC components, storage and flexible loads.

Keyword arguments, if any, are forwarded to `PowerModels.parse_file()`.
"""
function parse_file(file::String; kwargs...)
    data = _PM.parse_file(file; kwargs...)
    if haskey(data, "busdc")
        _PMACDC.process_additional_data!(data)
    end
    add_storage_data!(data)
    add_flexible_demand_data!(data)
    return data
end

"""
    parse_file(file, scenario; <keyword arguments>)

Parse a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a FlexPlan data structure,
including DC components, storage and flexible loads; scale cost data according to `scenario`.

Keyword arguments, if any, are forwarded to `PowerModels.parse_file()`.
"""
function parse_file(file::String, scenario::Dict{String,Any}; kwargs...)
    data = parse_file(file; kwargs...)
    scale_cost_data!(data, scenario)
    return data
end
