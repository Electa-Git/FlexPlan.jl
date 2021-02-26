# Contains functions related to distribution networks but not specific to a particular model


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



## Variables

function variable_oltc_branch_transform(pm::_PM.AbstractWModels; kwargs...)
    variable_oltc_branch_transform_magnitude_sqr_inv(pm; kwargs...)
end

"variable: `0 <= ttmi[l]` for `l` in `oltc_branch`es"
function variable_oltc_branch_transform_magnitude_sqr_inv(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    ttmi = _PM.var(pm, nw)[:ttmi] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :oltc_branch)], base_name="$(nw)_ttmi",
        lower_bound = 0.0,
        start = 1.0 / _PM.ref(pm,nw,:oltc_branch,i,"tap")^2
    )

    if bounded
        for (i, br) in _PM.ref(pm, nw, :oltc_branch)
            JuMP.set_lower_bound(ttmi[i], 1.0 / br["tm_max"]^2 )
            JuMP.set_upper_bound(ttmi[i], 1.0 / br["tm_min"]^2 )
        end
    end

    report && _IM.sol_component_value(pm, nw, :branch, :ttmi, _PM.ids(pm, nw, :oltc_branch), ttmi)
end

function variable_oltc_ne_branch_transform(pm::_PM.AbstractWModels; kwargs...)
    variable_oltc_ne_branch_transform_magnitude_sqr_inv(pm; kwargs...)
end

"variable: `0 <= ttmi_ne[l]` for `l` in `oltc_ne_branch`es"
function variable_oltc_ne_branch_transform_magnitude_sqr_inv(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    ttmi_ne = _PM.var(pm, nw)[:ttmi_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :oltc_ne_branch)], base_name="$(nw)_ttmi_ne",
        lower_bound = 0.0,
        start = 1.0 / _PM.ref(pm,nw,:oltc_ne_branch,i,"tap")^2
    )

    if bounded
        for (i, br) in _PM.ref(pm, nw, :oltc_ne_branch)
            JuMP.set_lower_bound(ttmi_ne[i], 1.0 / br["tm_max"]^2 )
            JuMP.set_upper_bound(ttmi_ne[i], 1.0 / br["tm_min"]^2 )
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_branch, :ttmi, _PM.ids(pm, nw, :oltc_ne_branch), ttmi_ne)
end



## Constraint templates that group several other constraint templates, provided for convenience

function constraint_dist_branch_tnep(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    if isempty(ne_branch_ids(pm, i; nw = nw))
        if is_frb_branch(pm, i; nw = nw)
            if is_oltc_branch(pm, i; nw = nw)
                constraint_power_losses_oltc(pm, i; nw = nw)
                constraint_voltage_magnitude_difference_oltc(pm, i; nw = nw)
            else
                constraint_power_losses_frb(pm, i; nw = nw)
                constraint_voltage_magnitude_difference_frb(pm, i; nw = nw)
            end
        else
            _PM.constraint_power_losses(pm, i; nw = nw)
            _PM.constraint_voltage_magnitude_difference(pm, i; nw = nw)
        end
        _PM.constraint_voltage_angle_difference(pm, i; nw = nw)
        _PM.constraint_thermal_limit_from(pm, i; nw = nw)
        _PM.constraint_thermal_limit_to(pm, i; nw = nw)
    else
        expression_branch_indicator(pm, i; nw = nw)
        constraint_branch_complementarity(pm, i; nw = nw)
        if is_frb_branch(pm, i; nw = nw)
            if is_oltc_branch(pm, i; nw = nw)
                constraint_power_losses_oltc_on_off(pm, i; nw = nw)
                constraint_voltage_magnitude_difference_oltc_on_off(pm, i; nw = nw)
            else
                constraint_power_losses_frb_on_off(pm, i; nw = nw)
                constraint_voltage_magnitude_difference_frb_on_off(pm, i; nw = nw)
            end
        else
            constraint_power_losses_on_off(pm, i; nw = nw)
            constraint_voltage_magnitude_difference_on_off(pm, i; nw = nw)
        end
        _PM.constraint_voltage_angle_difference_on_off(pm, i; nw = nw)
        _PM.constraint_thermal_limit_from_on_off(pm, i; nw = nw)
        _PM.constraint_thermal_limit_to_on_off(pm, i; nw = nw)
    end
end

function constraint_dist_ne_branch_tnep(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    if ne_branch_replace(pm, i, nw = nw)
        if is_frb_ne_branch(pm, i, nw = nw)
            if is_oltc_ne_branch(pm, i, nw = nw)
                constraint_ne_power_losses_oltc(pm, i, nw = nw)
                constraint_ne_voltage_magnitude_difference_oltc(pm, i, nw = nw)
            else
                constraint_ne_power_losses_frb(pm, i, nw = nw)
                constraint_ne_voltage_magnitude_difference_frb(pm, i, nw = nw)
            end
        else
            constraint_ne_power_losses(pm, i, nw = nw)
            constraint_ne_voltage_magnitude_difference(pm, i, nw = nw)
        end
        _PM.constraint_ne_thermal_limit_from(pm, i, nw = nw)
        _PM.constraint_ne_thermal_limit_to(pm, i, nw = nw)
    else
        if is_frb_ne_branch(pm, i, nw = nw)
            if is_oltc_ne_branch(pm, i, nw = nw)
                Memento.error(_LOGGER, "addition of a candidate OLTC in parallel to an existing OLTC is not supported")
            else
                constraint_ne_power_losses_frb_parallel(pm, i, nw = nw)
                constraint_ne_voltage_magnitude_difference_frb_parallel(pm, i, nw = nw)
            end
        else
            constraint_ne_power_losses_parallel(pm, i, nw = nw)
            constraint_ne_voltage_magnitude_difference_parallel(pm, i, nw = nw)
        end
        constraint_ne_thermal_limit_from_parallel(pm, i, nw = nw)
        constraint_ne_thermal_limit_to_parallel(pm, i, nw = nw)
    end
    _PM.constraint_ne_voltage_angle_difference(pm, i, nw = nw)
end



## Constraint templates

"Defines voltage drop over a a branch whose `f_bus` is the reference bus"
function constraint_voltage_magnitude_difference_frb(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_voltage_magnitude_difference_frb(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end

"Defines voltage drop over a transformer branch that has an OLTC"
function constraint_voltage_magnitude_difference_oltc(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]

    constraint_voltage_magnitude_difference_oltc(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr)
end

"Defines branch flow model power flow equations for a branch whose `f_bus` is the reference bus"
function constraint_power_losses_frb(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    constraint_power_losses_frb(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end

"Defines branch flow model power flow equations for a transformer branch that has an OLTC"
function constraint_power_losses_oltc(pm::_PM.AbstractBFModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    constraint_power_losses_oltc(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to)
end

""
function constraint_ne_power_losses_frb(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ne_power_losses_frb(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

""
function constraint_ne_power_losses_oltc(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_ne_power_losses_oltc(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, vad_min, vad_max)
end

"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_ne_voltage_magnitude_difference_frb(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_ne_voltage_magnitude_difference_frb(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end

"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_ne_voltage_magnitude_difference_oltc(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :ne_branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm_min = branch["tm_min"]
    tm_max = branch["tm_max"]

    constraint_ne_voltage_magnitude_difference_oltc(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm_min, tm_max)
end



## Constraint implementations not limited to a specific model type

""
function constraint_ne_voltage_magnitude_difference_frb(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    branch = _PM.ref(pm, n, :ne_branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  1.0^2/tm^2 - to_bus["vmin"]^2
    M_lo   = -1.0^2/tm^2 + to_bus["vmax"]^2
    p_fr = _PM.var(pm, n, :p_ne, f_idx)
    q_fr = _PM.var(pm, n, :q_ne, f_idx)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :branch_ne, i)
    # w_fr is assumed equal to 1.0

    JuMP.@constraint(pm.model, (1.0/tm^2) - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, (1.0/tm^2) - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end

""
function constraint_ne_voltage_magnitude_difference_oltc(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm_min, tm_max)
    branch = _PM.ref(pm, n, :ne_branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  1.0^2/tm_min^2 - to_bus["vmin"]^2
    M_lo   = -1.0^2/tm_max^2 + to_bus["vmax"]^2
    p_fr = _PM.var(pm, n, :p_ne, f_idx)
    q_fr = _PM.var(pm, n, :q_ne, f_idx)
    ttmi = _PM.var(pm, n, :ttmi_ne, i)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :branch_ne, i)
    # w_fr is assumed equal to 1.0 to preserve the linearity of the model

    JuMP.@constraint(pm.model, 1.0*ttmi - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, 1.0*ttmi - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end
