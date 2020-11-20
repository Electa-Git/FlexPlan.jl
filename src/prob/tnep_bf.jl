# TNEP for branch flow formulations.
#
# Adapted from PowerModels/src/prob/tnep.jl.
# See also differences between PowerModels/src/prob/opf.jl and PowerModels/src/prob/opf_bf.jl.

""
function run_tnep_bf(file, model_type::Type, optimizer; kwargs...)
    return _PM.run_model(file, model_type, optimizer, build_tnep_bf; ref_extensions=[_PM.ref_add_on_off_va_bounds!,_PM.ref_add_ne_branch!], kwargs...)
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
        constraint_power_losses_radial(pm, i)
        constraint_voltage_magnitude_difference_radial(pm, i)

        constraint_voltage_angle_difference_radial(pm, i)

        constraint_thermal_limit_from_radial(pm, i)
        constraint_thermal_limit_to_radial(pm, i)
    end

    for i in _PM.ids(pm, :ne_branch)
        constraint_ne_power_losses_radial(pm, i)
        constraint_ne_voltage_magnitude_difference_radial(pm, i)

        _PM.constraint_ne_voltage_angle_difference(pm, i) # _radial variant is not needed

        constraint_ne_thermal_limit_from_radial(pm, i)
        constraint_ne_thermal_limit_to_radial(pm, i)
    end

    for i in _PM.ids(pm, :dcline)
        _PM.constraint_dcline_power_losses(pm, i)
    end
end
