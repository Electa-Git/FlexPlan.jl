# To be used instead of _PMACDC.variable_dc_converter_ne() - supports deduplication of variables
function variable_dc_converter_ne(pm::_PM.AbstractDCPModel; investment::Bool=true, kwargs...)
    variable_ne_converter_indicator(pm; kwargs..., relax=true) # FlexPlan version: replaces _PMACDC.variable_converter_ne().
    investment && variable_ne_converter_investment(pm; kwargs...)
    _PMACDC.variable_converter_active_power_ne(pm; kwargs...)
    _PMACDC.variable_dcside_power_ne(pm; kwargs...)
    _PMACDC.variable_converter_filter_voltage_ne(pm; kwargs...)
    _PMACDC.variable_converter_internal_voltage_ne(pm; kwargs...)
    _PMACDC.variable_converter_to_grid_active_power_ne(pm; kwargs...)

    _PMACDC.variable_conv_transformer_active_power_to_ne(pm; kwargs...)
    _PMACDC.variable_conv_reactor_active_power_from_ne(pm; kwargs...)
end
