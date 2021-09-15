# Contains problems defined exclusively on distribution networks

export opf_rad, tnep_rad


## Optimal power flow

"Optimal power flow problem for radial networks"
function opf_rad(data::Dict{String,Any}, model_type::Type{<:_PM.AbstractBFModel}, optimizer; kwargs...)
    return _PM.run_model(
        data, model_type, optimizer, build_opf_rad;
        ref_extensions = [ref_add_frb_branch!, ref_add_oltc_branch!],
        solution_processors = [_PM.sol_data_model!],
        kwargs...
    )
end

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


## Single-period network expansion planning
# (TNEP acronym is maintained for consistency with transmission networks.)

"Single-period network expansion planning problem for radial networks"
function tnep_rad(data::Dict{String,Any}, model_type::Type{<:_PM.AbstractBFModel}, optimizer; kwargs...)
    return _PM.run_model(
        data, model_type, optimizer, build_tnep_rad;
        ref_extensions = [_PM.ref_add_on_off_va_bounds!, ref_add_ne_branch_allbranches!, ref_add_frb_branch!, ref_add_oltc_branch!],
        solution_processors = [_PM.sol_data_model!],
        kwargs...
    )
end

function build_tnep_rad(pm::_PM.AbstractBFModel)
    _PM.variable_bus_voltage(pm)
    _PM.variable_gen_power(pm)
    _PM.variable_branch_power(pm)
    _PM.variable_branch_current(pm)
    variable_oltc_branch_transform(pm)

    _PM.variable_ne_branch_indicator(pm)
    _PM.variable_ne_branch_power(pm, bounded = false) # Bounds computed here would be too limiting in the case of ne_branches added in parallel
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
        constraint_dist_branch_tnep(pm, i)
    end

    for i in _PM.ids(pm, :ne_branch)
        constraint_dist_ne_branch_tnep(pm, i)
    end
end
