"""
    parse_file(file; flex_load=true, <keyword arguments>)

Parse a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a FlexPlan data structure,
including DC components, storage and flexible loads.

`flex_load` specifies whether to process flexible load data.
Other keyword arguments, if any, are forwarded to `PowerModels.parse_file()`.

Mandatory tables: `bus`, `gen`, `branch` (and `load_extra` if `flex_load==true`).
Optional tables: `gencost`, `branch_oltc`, `storage`, `storage_extra`, `ne_storage`.
Other tables can be added as well: they will be made available in the returned object.

"""
function parse_file(file::String; flex_load=false, kwargs...)
    data = _PM.parse_file(file; kwargs...)
    if !haskey(data, "ne_branch")
        data["ne_branch"] = Dict{String,Any}()
    end
    if haskey(data, "busdc") || haskey(data, "busdc_ne")
        _PMACDC.process_additional_data!(data)
    end
    add_storage_data!(data)
    if flex_load
        if !haskey(data, "load_extra")
            Memento.error(_LOGGER, "No `load_extra` table found in input file.")
        end
        add_flexible_demand_data!(data)
    end
    return data
end
