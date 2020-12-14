# Problems defined on distribution networks


## Network expansion planning
# (TNEP acronym is maintained for consistency with transmission networks.)


""
function run_tnep_bf(file, model_type::Type, optimizer; kwargs...)
    return _PM.run_model(file, model_type, optimizer, build_tnep_bf; ref_extensions=[_PM.ref_add_on_off_va_bounds!,ref_add_ne_branch_parallel!], kwargs...)
end

"the general form of the tnep optimization model for branch flow formulations"
function build_tnep_bf(pm::_PM.AbstractPowerModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_current(pm)
    _PM.variable_dcline_power(pm)

    _PM.variable_ne_branch_indicator(pm)
    _PM.variable_ne_branch_power(pm)
    variable_ne_branch_current(pm)

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
            _PM.constraint_power_losses(pm, i)
            _PM.constraint_voltage_magnitude_difference(pm, i)
            _PM.constraint_voltage_angle_difference(pm, i)
            _PM.constraint_thermal_limit_from(pm, i)
            _PM.constraint_thermal_limit_to(pm, i)
        else
            expression_branch_indicator(pm, i)    
            constraint_branch_complementarity(pm, i)

            constraint_power_losses_on_off(pm, i)
            constraint_voltage_magnitude_difference_on_off(pm, i)
            _PM.constraint_voltage_angle_difference_on_off(pm, i)
            _PM.constraint_thermal_limit_from_on_off(pm, i)
            _PM.constraint_thermal_limit_to_on_off(pm, i)
        end
    end

    for i in _PM.ids(pm, :ne_branch)
        if ne_branch_replace(pm, i)
            constraint_ne_power_losses(pm, i)
            constraint_ne_voltage_magnitude_difference(pm, i)
            _PM.constraint_ne_thermal_limit_from(pm, i)
            _PM.constraint_ne_thermal_limit_to(pm, i)
        else
            constraint_ne_power_losses_parallel(pm, i)
            constraint_ne_voltage_magnitude_difference_parallel(pm, i)
            constraint_ne_thermal_limit_from_parallel(pm, i)
            constraint_ne_thermal_limit_to_parallel(pm, i)
        end
        _PM.constraint_ne_voltage_angle_difference(pm, i) # independent of replacement behavior
    end

    for i in _PM.ids(pm, :dcline)
        _PM.constraint_dcline_power_losses(pm, i)
    end
end

"like ref_add_ne_branch!, but ne_buspairs are built using calc_buspair_parameters_parallel"
function ref_add_ne_branch_parallel!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
    for (nw, nw_ref) in ref[:nw]
        if !haskey(nw_ref, :ne_branch)
            error(_LOGGER, "required ne_branch data not found")
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
            nw_ref[:ne_buspairs] = calc_buspair_parameters_parallel(nw_ref[:bus], nw_ref[:ne_branch], cid, ismc)
        end
    end
end

"like calc_buspair_parameters, but retains indices of all the branches and drops keys that depend on branch"
function calc_buspair_parameters_parallel(buses, branches, conductor_ids, ismulticondcutor)
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
