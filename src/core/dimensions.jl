"""
    add_dimension!(data, name, properties; metadata)

Add dimension `name` to `data` specifying some `properties` of the dimension ids.

# Arguments
- `data::Dict{String,Any}`: a single-network data structure.
- `name::Symbol`: the name to use to refer to the dimension in the code.
- `properties::Dict{Int,Dict{String,Any}}`: properties associated to the dimension ids. The
  outer dictionary is indexed with the ids along the dimension (consecutive `Int`s starting
  from 1). The inner dictionaries, one for each id, store the properties.
- `metadata::Dict{String,Any} = Dict{String,Any}()`: optional metadata describing the
  dimension as a whole.

# Examples
```julia-repl
julia> add_dimension!(data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/4) for s in 1:4))
```

# Extended help
Once a PowerModel `pm` is instantiated from `data`, a dimension `<name>` is accessible
through `pm.ref[:dim]`:
- properties: `pm.ref[:dim][:<name>][<Int_id_along_dimension>]["<property_key>"]`;
- metadata: `pm.ref[:dim][:meta][:<name>]["<metadata_key>"]`.

The same information is stored in `data["dim"]` and is accessible even before instantiating
a PowerModel.
"""
function add_dimension!(data::Dict{String,Any}, name::Symbol, properties::Dict{Int,Dict{String,Any}}; metadata::Dict{String,Any}=Dict{String,Any}())
    if name in (:ids, :ids_lookup, :meta, :names)
        Memento.error(_LOGGER, "\"$name\" cannot be used as dimension name because is reserved.")
    end
    dim = get!(data, "dim", Dict{Symbol,Any}(:meta=>Dict{Symbol,Any}(), :names=>Vector{Symbol}()) )
    if haskey(dim, name)
        Memento.error(_LOGGER, "A dimension named \"$name\" is already present in data.")
    end
    push!(dim[:names], name)
    if Set(keys(properties)) != Set(1:length(properties))
        Memento.error(_LOGGER, "Keys of `properties` Dict must range from 1 to the number of $(name)s.")
    end
    dim[name] = properties
    if haskey(metadata, "order")
        Memento.error(_LOGGER, "\"order\" cannot be used as metadata key because is reserved.")
    end
    metadata["order"] = length(dim[:names])
    dim[:meta][name] = metadata
    dim[:ids] = collect(LinearIndices(Tuple(1:length(dim[name]) for name in dim[:names])))
    dim[:ids_lookup] = CartesianIndices(dim[:ids])
    return nothing
end

"""
    add_dimension!(data, name, size; metadata)

Add dimension `name` to `data` specifying the dimension `size`.

# Examples
```julia-repl
julia> add_dimension!(data, :hour, 24)
```
"""
function add_dimension!(data::Dict{String,Any}, name::Symbol, size::Int; metadata::Dict{String,Any}=Dict{String,Any}())
    properties = Dict{Int,Dict{String,Any}}(i => Dict{String,Any}() for i in 1:size)
    add_dimension!(data, name, properties; metadata)
end

"""
    is_first_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol)

Return whether the network `n` is the first along `dimension` in `pm`.
"""
function is_first_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol)
    dim = pm.ref[:dim]
    order = dim[:meta][dimension]["order"]
    id_along_dim = dim[:ids_lookup][n][order]
    return id_along_dim == 1
end

"""
    is_last_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol)

Return whether the network `n` is the last along `dimension` in `pm`.
"""
function is_last_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol)
    dim = pm.ref[:dim]
    order = dim[:meta][dimension]["order"]
    id_along_dim = dim[:ids_lookup][n][order]
    return id_along_dim == length(dim[dimension])
end

"""
    first_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol...)

Return the first network in `pm` along `dimension` while keeping the other dimensions fixed.
"""
function first_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol...)
    dim = pm.ref[:dim]
    for d in dimension
        order = dim[:meta][d]["order"]
        id_along_dim = dim[:ids_lookup][n][order]
        step = stride(dim[:ids], order)
        n = n - step * (id_along_dim-1)
    end
    return n
end

"""
    last_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol...)

Return the last network in `pm` along `dimension` while keeping the other dimensions fixed.
"""
function last_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol...)
    dim = pm.ref[:dim]
    for d in dimension
        order = dim[:meta][d]["order"]
        id_along_dim = dim[:ids_lookup][n][order]
        step = stride(dim[:ids], order)
        n = n + step * (length(dim[d])-id_along_dim)
    end
    return n
end

"""
    prev_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol)

Return the previous network in `pm` along `dimension` while keeping the other dimensions fixed.
"""
function prev_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol)
    dim = pm.ref[:dim]
    order = dim[:meta][dimension]["order"]
    id_along_dim = dim[:ids_lookup][n][order]
    if id_along_dim == 1
        Memento.error(_LOGGER, "Attempt to access the id of the $dimension before the first.")
    end
    step = stride(dim[:ids], order)
    return n - step
end

"""
    next_nw(pm::PowerModels.AbstractPowerModel, n::Int, dimension::Symbol)

Return the next network in `pm` along `dimension` while keeping the other dimensions fixed.
"""
function next_nw(pm::_PM.AbstractPowerModel, n::Int, dimension::Symbol)
    dim = pm.ref[:dim]
    order = dim[:meta][dimension]["order"]
    id_along_dim = dim[:ids_lookup][n][order]
    if id_along_dim == length(dim[dimension])
        Memento.error(_LOGGER, "Attempt to access the id of the $dimension after the last.")
    end
    step = stride(dim[:ids], order)
    return n + step
end
