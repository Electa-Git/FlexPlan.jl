## Variables

function _PMACDC.variable_dcgrid_voltage_magnitude_ne(pm::_PM.AbstractBFAModel; kwargs...)
    _PMACDC.variable_dcgrid_voltage_magnitude_sqr_ne(pm; kwargs...)
end

function _PMACDC.variable_dcgrid_voltage_magnitude_sqr(pm::_PM.AbstractBFAModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    wdc = _PM.var(pm, nw)[:wdc] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :busdc)],
        base_name = "$(nw)_wdc",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc, i), "Vdc", 1.0)^2
    )

    if bounded
        for (i, busdc) in _PM.ref(pm, nw, :busdc)
            JuMP.set_lower_bound(wdc[i], busdc["Vdcmin"]^2)
            JuMP.set_upper_bound(wdc[i], busdc["Vdcmax"]^2)
        end
    end

    report && _PM.sol_component_value(pm, nw, :busdc, :wdc, _PM.ids(pm, nw, :busdc), wdc)
end

function _PMACDC.variable_dcgrid_voltage_magnitude_sqr_ne(pm::_PM.AbstractBFAModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
    wdc_ne = _PM.var(pm, nw)[:wdc_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :busdc_ne)],
        base_name = "$(nw)_wdc_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :busdc_ne, i), "Vdc", 1.0)^2,
    )
    if bounded
        for (i, busdc) in _PM.ref(pm, nw, :busdc_ne)
            JuMP.set_lower_bound(wdc_ne[i], busdc["Vdcmin"]^2)
            JuMP.set_upper_bound(wdc_ne[i], busdc["Vdcmax"]^2)
        end
    end
    report && _PM.sol_component_value(pm, nw, :busdc_ne, :wdc_ne, _PM.ids(pm, nw, :busdc_ne), wdc_ne)
end

function _PMACDC.variable_dcbranch_current(pm::_PM.AbstractBFAModel; kwargs...)
end

function _PMACDC.variable_dcbranch_current_ne(pm::_PM.AbstractBFAModel; kwargs...)
end

function _PMACDC.variable_converter_filter_voltage_ne(pm::_PM.AbstractBFAModel; kwargs...)
    _PMACDC.variable_converter_filter_voltage_magnitude_sqr_ne(pm; kwargs...)
end

function _PMACDC.variable_converter_filter_voltage(pm::_PM.AbstractBFAModel; kwargs...)
    _PMACDC.variable_converter_filter_voltage_magnitude_sqr(pm; kwargs...)
end

function _PMACDC.variable_converter_internal_voltage(pm::_PM.AbstractBFAModel; kwargs...)
    _PMACDC.variable_converter_internal_voltage_magnitude_sqr(pm; kwargs...)
end

function _PMACDC.variable_converter_internal_voltage_ne(pm::_PM.AbstractBFAModel; kwargs...)
    _PMACDC.variable_converter_internal_voltage_magnitude_sqr_ne(pm; kwargs...)
end

function _PMACDC.variable_acside_current(pm::_PM.AbstractBFAModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
end

function _PMACDC.variable_acside_current_ne(pm::_PM.AbstractBFAModel; nw::Int=_PM.nw_id_default, bounded::Bool = true, report::Bool=true)
end


## Constraints

function _PMACDC.constraint_ohms_dc_branch(pm::_PM.AbstractBFAModel, n::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    p_dc_fr = _PM.var(pm, n, :p_dcgrid, f_idx)
    p_dc_to = _PM.var(pm, n, :p_dcgrid, t_idx)
    wdc_fr = _PM.var(pm, n, :wdc, f_bus)
    wdc_to = _PM.var(pm, n, :wdc, t_bus)

    JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
    JuMP.@constraint(pm.model, wdc_fr - wdc_to == 2r * (p_dc_fr/p))
end

function _PMACDC.constraint_ohms_dc_branch_ne(pm::_PM.AbstractBFAModel, n::Int, f_bus, t_bus, f_idx, t_idx, r, p)
    l = f_idx[1];

    p_dc_fr        = _PM.var(pm, n, :p_dcgrid_ne, f_idx)
    p_dc_to        = _PM.var(pm, n, :p_dcgrid_ne, t_idx)
    wdc_to, wdc_fr = _PMACDC.contraint_ohms_dc_branch_busvoltage_structure_W(pm, n, f_bus, t_bus, nothing, nothing)
    z              = _PM.var(pm, n, :branchdc_ne, l)

    Δwdc_max   = JuMP.upper_bound(wdc_fr) - JuMP.lower_bound(wdc_to)
    Δwdc_min   = JuMP.lower_bound(wdc_fr) - JuMP.upper_bound(wdc_to)
    Δwdc_range = Δwdc_max - Δwdc_min
    bigM_u     = Δwdc_max + Δwdc_range
    bigM_l     = Δwdc_min - Δwdc_range # ≤ 0

    JuMP.@constraint(pm.model, p_dc_fr + p_dc_to == 0)
    JuMP.@constraint(pm.model, wdc_fr - wdc_to <= 2r*(p_dc_fr/p) + bigM_u*(1-z))
    JuMP.@constraint(pm.model, wdc_fr - wdc_to >= 2r*(p_dc_fr/p) + bigM_l*(1-z))
end

function _PMACDC.constraint_branch_limit_on_off(pm::_PM.AbstractBFAModel, n::Int, i, f_idx, t_idx, pmax, pmin, imax, imin)
    p_fr = _PM.var(pm, n, :p_dcgrid_ne, f_idx)
    p_to = _PM.var(pm, n, :p_dcgrid_ne, t_idx)
    z    = _PM.var(pm, n, :branchdc_ne, i)

    JuMP.@constraint(pm.model, p_fr <= pmax * z)
    JuMP.@constraint(pm.model, p_fr >= pmin * z)
    JuMP.@constraint(pm.model, p_to <= pmax * z)
    JuMP.@constraint(pm.model, p_to >= pmin * z)
end

function _PMACDC.constraint_conv_transformer(pm::_PM.AbstractBFAModel, n::Int, i::Int, rtf, xtf, acbus, tm, transformer)
    ptf_fr = _PM.var(pm, n, :pconv_tf_fr, i)
    qtf_fr = _PM.var(pm, n, :qconv_tf_fr, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to, i)
    w      = _PM.var(pm, n, :w, acbus)
    wf     = _PM.var(pm, n, :wf_ac, i)

    JuMP.@constraint(pm.model, ptf_fr + ptf_to == 0)
    JuMP.@constraint(pm.model, qtf_fr + qtf_to == 0)
    if transformer
        JuMP.@constraint(pm.model, wf == w/tm^2 - 2*(rtf*ptf_fr + xtf*qtf_fr))
    else
        JuMP.@constraint(pm.model, wf == w )
    end
end

function _PMACDC.constraint_conv_transformer_ne(pm::_PM.AbstractBFAModel, n::Int, i::Int, rtf, xtf, acbus, tm, transformer)
    ptf_fr = _PM.var(pm, n, :pconv_tf_fr_ne, i)
    qtf_fr = _PM.var(pm, n, :qconv_tf_fr_ne, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to_ne, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to_ne, i)
    w      = _PM.var(pm, n, :w, acbus)
    wf     = _PM.var(pm, n, :wf_ac_ne, i)

    JuMP.@constraint(pm.model, ptf_fr + ptf_to == 0)
    JuMP.@constraint(pm.model, qtf_fr + qtf_to == 0)
    if transformer
        JuMP.@constraint(pm.model, wf == w/tm^2 - 2*(rtf*ptf_fr + xtf*qtf_fr))
    else
        JuMP.@constraint(pm.model, wf == w)
    end
end

function _PMACDC.constraint_conv_filter_ne(pm::_PM.AbstractBFAModel, n::Int, i::Int, bf, filter)
    ppr_fr = _PM.var(pm, n, :pconv_pr_fr_ne, i)
    qpr_fr = _PM.var(pm, n, :qconv_pr_fr_ne, i)
    ptf_to = _PM.var(pm, n, :pconv_tf_to_ne, i)
    qtf_to = _PM.var(pm, n, :qconv_tf_to_ne, i)
    wf     = _PM.var(pm, n, :wf_ac_ne, i)
    z      = _PM.var(pm, n, :conv_ne, i)

    bigM = bf * JuMP.upper_bound(wf)

    JuMP.@constraint(pm.model, ppr_fr + ptf_to == 0 )
    if filter
        JuMP.@constraint(pm.model, qpr_fr + qtf_to >= bf*wf - bigM*(1-z))
        JuMP.@constraint(pm.model, qpr_fr + qtf_to <= bf*wf)
    else
        JuMP.@constraint(pm.model, qpr_fr + qtf_to == 0)
    end
end

function _PMACDC.constraint_conv_reactor(pm::_PM.AbstractBFAModel, n::Int, i::Int, rc, xc, reactor)
    ppr_fr   = _PM.var(pm, n, :pconv_pr_fr, i)
    qpr_fr   = _PM.var(pm, n, :qconv_pr_fr, i)
    pconv_ac = _PM.var(pm, n, :pconv_ac, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac, i)
    ppr_to   = - pconv_ac
    qpr_to   = - qconv_ac
    wf       = _PM.var(pm, n, :wf_ac, i)
    wc       = _PM.var(pm, n, :wc_ac, i)

    JuMP.@constraint(pm.model, ppr_fr + ppr_to == 0)
    JuMP.@constraint(pm.model, qpr_fr + qpr_to == 0)
    if reactor
        JuMP.@constraint(pm.model, wc == wf - 2*(rc*ppr_fr + xc*qpr_fr))
    else
        JuMP.@constraint(pm.model, wc == wf)
    end
end

function _PMACDC.constraint_conv_reactor_ne(pm::_PM.AbstractBFAModel, n::Int, i::Int, rc, xc, reactor)
    ppr_fr   = _PM.var(pm, n, :pconv_pr_fr_ne, i)
    qpr_fr   = _PM.var(pm, n, :qconv_pr_fr_ne, i)
    pconv_ac = _PM.var(pm, n, :pconv_ac_ne, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac_ne, i)
    ppr_to   = - pconv_ac
    qpr_to   = - qconv_ac
    wf       = _PM.var(pm, n, :wf_ac_ne, i)
    wc       = _PM.var(pm, n, :wc_ac_ne, i)

    JuMP.@constraint(pm.model, ppr_fr + ppr_to == 0)
    JuMP.@constraint(pm.model, qpr_fr + qpr_to == 0)
    if reactor
        JuMP.@constraint(pm.model, wc == wf - 2*(rc*ppr_fr + xc*qpr_fr))
    else
        JuMP.@constraint(pm.model, wc == wf )
    end
end

function _PMACDC.constraint_converter_current(pm::_PM.AbstractBFAModel, n::Int, i::Int, Umax, Imax)
end

function _PMACDC.constraint_converter_current_ne(pm::_PM.AbstractBFAModel, n::Int, i::Int, Umax, Imax)
end

function _PMACDC.constraint_converter_limit_on_off(pm::_PM.AbstractBFAModel, n::Int, i, pmax, pmin, qmax, qmin, pmaxdc, pmindc, imax)
    # Converter
    pconv_ac = _PM.var(pm, n, :pconv_ac_ne, i)
    pconv_dc = _PM.var(pm, n, :pconv_dc_ne, i)
    qconv_ac = _PM.var(pm, n, :qconv_ac_ne, i)
    z        = _PM.var(pm, n, :conv_ne, i)
    JuMP.@constraint(pm.model, pconv_ac <= pmax * z)
    JuMP.@constraint(pm.model, pconv_ac >= pmin * z)
    JuMP.@constraint(pm.model, pconv_dc <= pmaxdc * z)
    JuMP.@constraint(pm.model, pconv_dc >= pmindc * z)
    JuMP.@constraint(pm.model, qconv_ac <= qmax * z)
    JuMP.@constraint(pm.model, qconv_ac >= qmin * z)

    # Transformer
    pconv_tf_fr = _PM.var(pm, n, :pconv_tf_fr_ne, i)
    pconv_tf_to = _PM.var(pm, n, :pconv_tf_to_ne, i)
    qconv_tf_fr = _PM.var(pm, n, :qconv_tf_fr_ne, i)
    qconv_tf_to = _PM.var(pm, n, :qconv_tf_to_ne, i)
    JuMP.@constraint(pm.model, pconv_tf_fr <= pmax * z)
    JuMP.@constraint(pm.model, pconv_tf_fr >= pmin * z)
    JuMP.@constraint(pm.model, pconv_tf_to <= pmax * z)
    JuMP.@constraint(pm.model, pconv_tf_to >= pmin * z)
    JuMP.@constraint(pm.model, qconv_tf_fr <= qmax * z)
    JuMP.@constraint(pm.model, qconv_tf_fr >= qmin * z)
    JuMP.@constraint(pm.model, qconv_tf_to <= qmax * z)
    JuMP.@constraint(pm.model, qconv_tf_to >= qmin * z)

    # Filter

    # Reactor
    pconv_pr_fr = _PM.var(pm, n, :pconv_pr_fr_ne, i)
    qconv_pr_fr = _PM.var(pm, n, :qconv_pr_fr_ne, i)
    JuMP.@constraint(pm.model, pconv_pr_fr <= pmax * z)
    JuMP.@constraint(pm.model, pconv_pr_fr >= pmin * z)
    JuMP.@constraint(pm.model, qconv_pr_fr <= qmax * z)
    JuMP.@constraint(pm.model, qconv_pr_fr >= qmin * z)
end
