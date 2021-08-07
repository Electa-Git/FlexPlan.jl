# Extends InfrastructureModels/src/core/base.jl

"""
    nw_ids(pm::PowerModels.AbstractPowerModel; kwargs...)

Return the sorted nw ids of `pm`, optionally filtered by the value of one or more dimensions.

`kwargs` must be of the form `name = <value>` or `name = <interval>` or `name = <subset>`,
where `name` is the name of a dimension of `pm`.

# Examples
```julia-repl
julia> nw_ids(pm)
julia> nw_ids(pm; hour = 24)
julia> nw_ids(pm; hour = 13:24)
julia> nw_ids(pm; hour = [6,12,18,24])
julia> nw_ids(pm; hour = 24, scenario = 3)
```
"""
function nw_ids(pm::_PM.AbstractPowerModel; kwargs...)
    dim = pm.ref[:dim]
    return vec(dim[:ids][(get(kwargs, name, 1:length(dim[name])) for name in dim[:names])...])
end

"""
    dim(pm::PowerModels.AbstractPowerModel, dimension::Symbol)

Return a `Dict` containing the properties of `dimension`.

Keys are `Int` ids ranging from 1 to the length of `dimension`.
Values are `Dict`s which have property names as keys and their values as values.
"""
function dim(pm::_PM.AbstractPowerModel, dimension::Symbol)
    return pm.ref[:dim][dimension]
end

"""
    dim_meta(pm::PowerModels.AbstractPowerModel, dimension::Symbol)

Return a `Dict` containing the metadata of `dimension`.
"""
function dim_meta(pm::_PM.AbstractPowerModel, dimension::Symbol)
    return pm.ref[:dim][:meta][dimension]
end

"""
    dim_meta(pm::PowerModels.AbstractPowerModel, dimension::Symbol, key::String)

Return the value of the metadata `key` of `dimension`.
"""
function dim_meta(pm::_PM.AbstractPowerModel, dimension::Symbol, key::String)
    return pm.ref[:dim][:meta][dimension][key]
end
