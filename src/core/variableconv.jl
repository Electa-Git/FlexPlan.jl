# To be used instead of _PMACDC.variable_converter_ne() - supports Benders decomposition
function variable_converter_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if haskey(_PM.ref(pm, nw), :benders) && _PM.ref(pm, nw, :benders, "first_nw") != nw
        first_nw = _PM.ref(pm, nw, :benders, "first_nw")
        Z_dc_conv_ne = _PM.var(pm, nw)[:conv_ne] = _PM.var(pm, first_nw)[:conv_ne]
    else
        if !relax
            Z_dc_conv_ne = _PM.var(pm, nw)[:conv_ne] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :convdc_ne)], base_name="$(nw)_conv_ne",
            binary = true,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc_ne, i), "branchdc_tnep_start", 1.0)
            )
        else
            Z_dc_conv_ne = _PM.var(pm, nw)[:conv_ne] = JuMP.@variable(pm.model,
            [i in _PM.ids(pm, nw, :convdc_ne)], base_name="$(nw)_conv_ne",
            lower_bound = 0,
            upper_bound = 1,
            start = _PM.comp_start_value(_PM.ref(pm, nw, :convdc_ne, i), "branchdc_tnep_start", 1.0)
            )
        end
    end
    report && _IM.sol_component_value(pm, nw, :convdc_ne, :isbuilt, _PM.ids(pm, nw, :convdc_ne), Z_dc_conv_ne)
end

# To be used instead of _PMACDC.variable_dc_converter_ne() - supports Benders decomposition
function variable_dc_converter_ne(pm::_PM.AbstractPowerModel; kwargs...)
    _PMACDC.variable_conv_tranformer_flow_ne(pm; kwargs...)
    _PMACDC.variable_conv_reactor_flow_ne(pm; kwargs...)
    variable_converter_ne(pm; kwargs...) # FlexPlan version: replaces that of PowerModelsACDC.

    _PMACDC.variable_converter_active_power_ne(pm; kwargs...)
    _PMACDC.variable_converter_reactive_power_ne(pm; kwargs...)
    _PMACDC.variable_acside_current_ne(pm; kwargs...)
    _PMACDC.variable_dcside_power_ne(pm; kwargs...)
    # _PMACDC.variable_converter_firing_angle_ne(pm; kwargs...)

    _PMACDC.variable_converter_filter_voltage_ne(pm; kwargs...)
    _PMACDC.variable_converter_internal_voltage_ne(pm; kwargs...)
    #
    _PMACDC.variable_converter_to_grid_active_power_ne(pm; kwargs...)
    _PMACDC.variable_converter_to_grid_reactive_power_ne(pm; kwargs...)
end


