###########################################################
############ new storage to refernce model
##########################################################
function add_candidate_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    for (n, nw_ref) in ref[:nw]
        if haskey(nw_ref, :ne_storage)
            bus_storage_ne = Dict([(i, []) for (i,bus) in nw_ref[:bus]])
            for (i,storage) in nw_ref[:ne_storage]
                push!(bus_storage_ne[storage["storage_bus"]], i)
            end
            nw_ref[:bus_storage_ne] = bus_storage_ne
        end
    end
end