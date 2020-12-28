# Contains: problems defined on distribution networks; related functions

export opf_rad, tnep_rad, strg_tnep_rad

## Problems defined on distribution networks


### Optimal power flow

""
function opf_rad(data::Dict{String,Any}, model_type::Type{T}, optimizer; kwargs...) where T <: _PM.AbstractBFModel
    return _PM.run_model(data, model_type, optimizer, build_opf_rad;
                         ref_extensions = [ref_add_frb_branch!, ref_add_oltc_branch!],
                         solution_processors = [_PM.sol_data_model!],
                         kwargs...)
end

"Optimal power flow problem for radial networks"
function build_opf_rad(pm::_PM.AbstractBFModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_current(pm)
    variable_oltc_branch_transform(pm)

    _PM.objective_min_fuel_and_flow_cost(pm)

    _PM.constraint_model_current(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PM.constraint_power_balance(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        if is_frb_branch(pm, i)
            if is_oltc_branch(pm, i)
                constraint_power_losses_oltc(pm, i)
                constraint_voltage_magnitude_difference_oltc(pm, i)
            else
                constraint_power_losses_frb(pm, i)
                constraint_voltage_magnitude_difference_frb(pm, i)
            end
        else
            _PM.constraint_power_losses(pm, i)
            _PM.constraint_voltage_magnitude_difference(pm, i)
        end
        _PM.constraint_voltage_angle_difference(pm, i)
        _PM.constraint_thermal_limit_from(pm, i)
        _PM.constraint_thermal_limit_to(pm, i)
    end
end


### Network expansion planning
# (TNEP acronym is maintained for consistency with transmission networks.)

""
function tnep_rad(data::Dict{String,Any}, model_type::Type{T}, optimizer; kwargs...) where T <: _PM.AbstractBFModel
    return _PM.run_model(data, model_type, optimizer, build_tnep_rad;
                         ref_extensions = [_PM.ref_add_on_off_va_bounds!, ref_add_ne_branch_allbranches!, ref_add_frb_branch!, ref_add_oltc_branch!],
                         solution_processors = [_PM.sol_data_model!],
                         kwargs...)
end

""
function strg_tnep_rad(data::Dict{String,Any}, model_type::Type{T}, optimizer; kwargs...) where T <: _PM.AbstractBFModel
    return _PM.run_model(data, model_type, optimizer, post_strg_tnep;
                         ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, ref_add_ne_branch_allbranches!, ref_add_frb_branch!, ref_add_oltc_branch!],
                         solution_processors = [_PM.sol_data_model!],
                         kwargs...)
end

"Network expansion planning problem for radial networks"
function build_tnep_rad(pm::_PM.AbstractBFModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_current(pm)
    variable_oltc_branch_transform(pm)

    _PM.variable_ne_branch_indicator(pm)
    _PM.variable_ne_branch_power(pm)
    variable_ne_branch_current(pm)
    variable_oltc_ne_branch_transform(pm)

    _PM.objective_tnep_cost(pm)

    _PM.constraint_model_current(pm)
    constraint_ne_model_current(pm)

    for i in _PM.ids(pm, :ref_buses)
        _PM.constraint_theta_ref(pm, i)
    end

    for i in _PM.ids(pm, :bus)
        _PM.constraint_ne_power_balance(pm, i)
    end

    for i in _PM.ids(pm, :branch)
        if isempty(ne_branch_ids(pm, i))
            if is_frb_branch(pm, i)
                if is_oltc_branch(pm, i)
                    constraint_power_losses_oltc(pm, i)
                    constraint_voltage_magnitude_difference_oltc(pm, i)
                else
                    constraint_power_losses_frb(pm, i)
                    constraint_voltage_magnitude_difference_frb(pm, i)
                end
            else
                _PM.constraint_power_losses(pm, i)
                _PM.constraint_voltage_magnitude_difference(pm, i)
            end
            _PM.constraint_voltage_angle_difference(pm, i)
            _PM.constraint_thermal_limit_from(pm, i)
            _PM.constraint_thermal_limit_to(pm, i)
        else
            expression_branch_indicator(pm, i)    
            constraint_branch_complementarity(pm, i)

            if is_frb_branch(pm, i)
                if is_oltc_branch(pm, i)
                    constraint_power_losses_oltc_on_off(pm, i)
                    constraint_voltage_magnitude_difference_oltc_on_off(pm, i)
                else
                    constraint_power_losses_frb_on_off(pm, i)
                    constraint_voltage_magnitude_difference_frb_on_off(pm, i)
                end
            else
                constraint_power_losses_on_off(pm, i)
                constraint_voltage_magnitude_difference_on_off(pm, i)
            end
            _PM.constraint_voltage_angle_difference_on_off(pm, i)
            _PM.constraint_thermal_limit_from_on_off(pm, i)
            _PM.constraint_thermal_limit_to_on_off(pm, i)
        end
    end

    for i in _PM.ids(pm, :ne_branch)
        if ne_branch_replace(pm, i)
            if is_frb_ne_branch(pm, i)
                if is_oltc_ne_branch(pm, i)
                    constraint_ne_power_losses_oltc(pm, i)
                    constraint_ne_voltage_magnitude_difference_oltc(pm, i)
                else
                    constraint_ne_power_losses_frb(pm, i)
                    constraint_ne_voltage_magnitude_difference_frb(pm, i)
                end
            else
                constraint_ne_power_losses(pm, i)
                constraint_ne_voltage_magnitude_difference(pm, i)
            end
            _PM.constraint_ne_thermal_limit_from(pm, i)
            _PM.constraint_ne_thermal_limit_to(pm, i)
        else
            if is_frb_ne_branch(pm, i)
                if is_oltc_ne_branch(pm, i)
                    Memento.error(_LOGGER, "addition of a candidate OLTC in parallel to an existing OLTC is not supported")
                else
                    constraint_ne_power_losses_frb_parallel(pm, i)
                    constraint_ne_voltage_magnitude_difference_frb_parallel(pm, i)
                end
            else
                constraint_ne_power_losses_parallel(pm, i)
                constraint_ne_voltage_magnitude_difference_parallel(pm, i)
            end
            constraint_ne_thermal_limit_from_parallel(pm, i)
            constraint_ne_thermal_limit_to_parallel(pm, i)
        end
        _PM.constraint_ne_voltage_angle_difference(pm, i)
    end
end



## Functions that add or edit model references

"like ref_add_ne_branch!, but ne_buspairs are built using calc_buspair_parameters_allbranches"
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

"like calc_buspair_parameters, but retains indices of all the branches and drops keys that depend on branch"
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


## Lookup functions, to build the constraint selection logic

"Return whether the `f_bus` of branch `i` is the reference bus."
function is_frb_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    return haskey(_PM.ref(pm, nw, :frb_branch), i)
end

"Return whether the `f_bus` of ne_branch `i` is the reference bus."
function is_frb_ne_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    return haskey(_PM.ref(pm, nw, :frb_ne_branch), i)
end

"Return whether branch `i` is an OLTC."
function is_oltc_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    return haskey(_PM.ref(pm, nw, :oltc_branch), i)
end

"Return whether ne_branch `i` is an OLTC."
function is_oltc_ne_branch(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    return haskey(_PM.ref(pm, nw, :oltc_ne_branch), i)
end
