## Storage

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


## Flexible loads

"Add to `ref` the keys for handling flexible demand"
function ref_add_flex_load!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})

    for (n, nw_ref) in ref[:nw]
        # Loads that can be made flexible, depending on investment decision
        nw_ref[:flex_load] = Dict(x for x in nw_ref[:load] if x.second["flex"] == 1)
        # Loads that are not flexible and do not have an associated investment decision
        nw_ref[:fixed_load] = Dict(x for x in nw_ref[:load] if x.second["flex"] == 0)
    end

    # Compute the total energy demand of each flex load and store it in the first hour nw
    for nw in nw_ids(data; hour = 1)
        if haskey(ref[:nw][nw], :time_elapsed)
            time_elapsed = ref[:nw][nw][:time_elapsed]
        else
            Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
            time_elapsed = 1.0
        end
        timeseries_nw_ids = similar_ids(data, nw, hour = 1:dim_length(data,:hour))
        for (l, load) in ref[:nw][nw][:flex_load]
            # `ref` instead of `data` must be used to access loads, since the former has
            # already been filtered to remove inactive loads.
            load["ed"] = time_elapsed * sum(ref[:nw][n][:load][l]["pd"] for n in timeseries_nw_ids)
        end
    end
end


## Distribution networks

"Like ref_add_ne_branch!, but ne_buspairs are built using calc_buspair_parameters_allbranches"
function ref_add_ne_branch_allbranches!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    for (nw, nw_ref) in ref[:nw]
        if !haskey(nw_ref, :ne_branch)
            Memento.error(_LOGGER, "required ne_branch data not found")
        end

        nw_ref[:ne_branch] = Dict(x for x in nw_ref[:ne_branch] if (x.second["br_status"] == 1 && x.second["f_bus"] in keys(nw_ref[:bus]) && x.second["t_bus"] in keys(nw_ref[:bus])))

        nw_ref[:ne_arcs_from] = [(i,branch["f_bus"],branch["t_bus"]) for (i,branch) in nw_ref[:ne_branch]]
        nw_ref[:ne_arcs_to]   = [(i,branch["t_bus"],branch["f_bus"]) for (i,branch) in nw_ref[:ne_branch]]
        nw_ref[:ne_arcs] = [nw_ref[:ne_arcs_from]; nw_ref[:ne_arcs_to]]

        ne_bus_arcs = Dict((i, []) for (i,bus) in nw_ref[:bus])
        for (l,i,j) in nw_ref[:ne_arcs]
            push!(ne_bus_arcs[i], (l,i,j))
        end
        nw_ref[:ne_bus_arcs] = ne_bus_arcs

        if !haskey(nw_ref, :ne_buspairs)
            ismc = haskey(nw_ref, :conductors)
            cid = nw_ref[:conductor_ids]
            nw_ref[:ne_buspairs] = calc_buspair_parameters_allbranches(nw_ref[:bus], nw_ref[:ne_branch], cid, ismc)
        end
    end
end

"""
Add to `ref` the following keys:
- `:frb_branch`: the set of `branch`es whose `f_bus` is the reference bus;
- `:frb_ne_branch`: the set of `ne_branch`es whose `f_bus` is the reference bus.
"""
function ref_add_frb_branch!(ref::Dict{Symbol,Any}, data::Dict{String,<:Any})
    for (nw, nw_ref) in ref[:nw]
        ref_bus_id = first(keys(nw_ref[:ref_buses]))

        frb_branch = Dict{Int,Any}()
        for (i,br) in nw_ref[:branch]
            if br["f_bus"] == ref_bus_id
                frb_branch[i] = br
            end
        end
        nw_ref[:frb_branch] = frb_branch

        if haskey(nw_ref, :ne_branch)
            frb_ne_branch = Dict{Int,Any}()
            for (i,br) in nw_ref[:ne_branch]
                if br["f_bus"] == ref_bus_id
                    frb_ne_branch[i] = br
                end
            end
            nw_ref[:frb_ne_branch] = frb_ne_branch
        end
    end
end

"""
Add to `ref` the following keys:
- `:oltc_branch`: the set of `frb_branch`es that are OLTCs;
- `:oltc_ne_branch`: the set of `frb_ne_branch`es that are OLTCs.
"""
function ref_add_oltc_branch!(ref::Dict{Symbol,Any}, data::Dict{String,<:Any})
    for (nw, nw_ref) in ref[:nw]
        if !haskey(nw_ref, :frb_branch)
            Memento.error(_LOGGER, "ref_add_oltc_branch! must be called after ref_add_frb_branch!")
        end
        oltc_branch = Dict{Int,Any}()
        for (i,br) in nw_ref[:frb_branch]
            if br["transformer"] && haskey(br, "tm_min") && haskey(br, "tm_max") && br["tm_min"] < br["tm_max"]
                oltc_branch[i] = br
            end
        end
        nw_ref[:oltc_branch] = oltc_branch

        if haskey(nw_ref, :frb_ne_branch)
            oltc_ne_branch = Dict{Int,Any}()
            for (i,br) in nw_ref[:ne_branch]
                if br["transformer"] && haskey(br, "tm_min") && haskey(br, "tm_max") && br["tm_min"] < br["tm_max"]
                    oltc_ne_branch[i] = br
                end
            end
            nw_ref[:oltc_ne_branch] = oltc_ne_branch
        end
    end
end

"Like calc_buspair_parameters, but retains indices of all the branches and drops keys that depend on branch"
function calc_buspair_parameters_allbranches(buses, branches, conductor_ids, ismulticondcutor)
    bus_lookup = Dict(bus["index"] => bus for (i,bus) in buses if bus["bus_type"] != 4)

    branch_lookup = Dict(branch["index"] => branch for (i,branch) in branches if branch["br_status"] == 1 && haskey(bus_lookup, branch["f_bus"]) && haskey(bus_lookup, branch["t_bus"]))

    buspair_indexes = Set((branch["f_bus"], branch["t_bus"]) for (i,branch) in branch_lookup)

    bp_branch = Dict((bp, Int[]) for bp in buspair_indexes)

    if ismulticondcutor
        bp_angmin = Dict((bp, [-Inf for c in conductor_ids]) for bp in buspair_indexes)
        bp_angmax = Dict((bp, [ Inf for c in conductor_ids]) for bp in buspair_indexes)
    else
        @assert(length(conductor_ids) == 1)
        bp_angmin = Dict((bp, -Inf) for bp in buspair_indexes)
        bp_angmax = Dict((bp,  Inf) for bp in buspair_indexes)
    end

    for (l,branch) in branch_lookup
        i = branch["f_bus"]
        j = branch["t_bus"]

        if ismulticondcutor
            for c in conductor_ids
                bp_angmin[(i,j)][c] = max(bp_angmin[(i,j)][c], branch["angmin"][c])
                bp_angmax[(i,j)][c] = min(bp_angmax[(i,j)][c], branch["angmax"][c])
            end
        else
            bp_angmin[(i,j)] = max(bp_angmin[(i,j)], branch["angmin"])
            bp_angmax[(i,j)] = min(bp_angmax[(i,j)], branch["angmax"])
        end

        bp_branch[(i,j)] = push!(bp_branch[(i,j)], l)
    end

    buspairs = Dict((i,j) => Dict(
        "branches"=>bp_branch[(i,j)],
        "angmin"=>bp_angmin[(i,j)],
        "angmax"=>bp_angmax[(i,j)],
        "vm_fr_min"=>bus_lookup[i]["vmin"],
        "vm_fr_max"=>bus_lookup[i]["vmax"],
        "vm_to_min"=>bus_lookup[j]["vmin"],
        "vm_to_max"=>bus_lookup[j]["vmax"]
        ) for (i,j) in buspair_indexes
    )

    return buspairs
end
