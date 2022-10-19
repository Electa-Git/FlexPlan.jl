# Extends PowerModels/src/form/bf.jl



## Variables

""
function variable_ne_branch_current(pm::_PM.AbstractBFModel; kwargs...)
    variable_ne_buspair_current_magnitude_sqr(pm; kwargs...)
end

""
function variable_ne_buspair_current_magnitude_sqr(pm::_PM.AbstractBFAModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
end



## Constraint templates

"""
This constraint captures problem agnostic constraints that are used to link
the model's current variables together, in addition to the standard problem
formulation constraints.  The network expansion name (ne) indicates that the
currents in this constraint can be set to zero via an indicator variable.
"""
function constraint_ne_model_current(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default)
    constraint_ne_model_current(pm, nw)
end

""
function constraint_ne_power_losses(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
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

    constraint_ne_power_losses(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

"""
Defines voltage drop over a branch, linking from and to side voltage magnitude
"""
function constraint_ne_voltage_magnitude_difference(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
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

    constraint_ne_voltage_magnitude_difference(pm, nw, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end


## Actual constraints

"""
do nothing, most models do not require any model-specific network expansion current constraints
"""
function constraint_ne_model_current(pm::_PM.AbstractPowerModel, n::Int)
end

""
function constraint_ne_voltage_magnitude_difference(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    branch = _PM.ref(pm, n, :ne_branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  fr_bus["vmax"]^2/tm^2 - to_bus["vmin"]^2
    M_lo   = -fr_bus["vmin"]^2/tm^2 + to_bus["vmax"]^2
    p_fr = _PM.var(pm, n, :p_ne, f_idx)
    q_fr = _PM.var(pm, n, :q_ne, f_idx)
    w_fr = _PM.var(pm, n, :w, f_bus)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :branch_ne, i)

    JuMP.@constraint(pm.model, (w_fr/tm^2) - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, (w_fr/tm^2) - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end
