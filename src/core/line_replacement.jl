## Expressions ##


### Expression templates ###

"Defines branch indicator as a function of corresponding ne_branch indicator variables."
function expression_branch_indicator(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    if !haskey(_PM.var(pm, nw), :z_branch)
        _PM.var(pm, nw)[:z_branch] = Dict{Int,Any}()
    end

    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    expression_branch_indicator(pm, nw, br_idx, f_bus, t_bus)
end


### Actual expressions ###

function expression_branch_indicator(pm::_PM.AbstractPowerModel, n::Int, br_idx, f_bus, t_bus)
    branch_ne_sum = sum(_PM.var(pm, n, :branch_ne, l) for l in _PM.ref(pm, n, :ne_buspairs, (f_bus,t_bus), "branches")) 

    _PM.var(pm, n, :z_branch)[br_idx] = 1 - branch_ne_sum
end



## Constraints ##


### Constraint templates ###

""
function constraint_ohms_yt_from_repl(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_fr = branch["g_fr"]
    b_fr = branch["b_fr"]
    tm = branch["tap"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)


    # track if a certain candidate branch is replacing a line 
    replace, ne_br_idx = replace_branch(pm, nw, f_bus, t_bus)
    # If lines is to be repalced use formulations below, else use PowerModels constraint for existing branches
    if replace  == 0
        _PM.constraint_ohms_yt_from(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    else
        constraint_ohms_yt_from_repl(pm, nw, ne_br_idx, f_bus, t_bus, f_idx, b, vad_min, vad_max)
    end
end

""
function constraint_ohms_yt_to_repl(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)
    t_idx = (i, t_bus, f_bus)

    g, b = _PM.calc_branch_y(branch)
    tr, ti = _PM.calc_branch_t(branch)
    g_to = branch["g_to"]
    b_to = branch["b_to"]
    tm = branch["tap"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    # track if a certain candidate branch is replacing a line 
    replace, ne_br_idx = replace_branch(pm, nw, f_bus, t_bus)
    # If lines is to be repalced use formulations below, else use PowerModels constraint for existing branches
    if replace  == 0
        _PM.constraint_ohms_yt_to(pm, nw, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    else
        constraint_ohms_yt_to_repl(pm, nw, ne_br_idx, f_bus, t_bus, t_idx, b, vad_min, vad_max)
    end
end

function constraint_voltage_angle_difference_repl(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, branch["f_bus"], branch["t_bus"])

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    # track if a certain candidate branch is replacing a line 
    replace, ne_br_idx = replace_branch(pm, nw, f_bus, t_bus)
    # If lines is to be repalced use formulations below, else use PowerModels constraint for existing branches
    if replace  == 0
        _PM.constraint_voltage_angle_difference(pm, nw, f_idx, branch["angmin"], branch["angmax"])
    else
        constraint_voltage_angle_difference_repl(pm, nw, ne_br_idx, f_idx, branch["angmin"], branch["angmax"], vad_min, vad_max)
    end
end

function constraint_thermal_limit_from_repl(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (i, f_bus, t_bus)

    if !haskey(branch, "rate_a")
        Memento.error(_LOGGER, "constraint_thermal_limit_from_ne requires a rate_a value on all branches, calc_thermal_limits! can be used to generate reasonable values")
    end

    # track if a certain candidate branch is replacing a line 
    replace, ne_br_idx = replace_branch(pm, nw, f_bus, t_bus)
    # If lines is to be repalced use formulations below, else use PowerModels constraint for existing branches
    if replace  == 0
        _PM.constraint_thermal_limit_from(pm, nw, f_idx, branch["rate_a"])
    else
        constraint_thermal_limit_from_repl(pm, nw, ne_br_idx, f_idx, branch["rate_a"])
    end
end

""
function constraint_thermal_limit_to_repl(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, i)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    t_idx = (i, t_bus, f_bus)

    if !haskey(branch, "rate_a")
        Memento.error(_LOGGER, "constraint_thermal_limit_to_ne requires a rate_a value on all branches, calc_thermal_limits! can be used to generate reasonable values")
    end
    # track if a certain candidate branch is replacing a line 
    replace, ne_br_idx = replace_branch(pm, nw, f_bus, t_bus)
    # If lines is to be repalced use formulations below, else use PowerModels constraint for existing branches
    if replace  == 0
        _PM.constraint_thermal_limit_to(pm, nw, t_idx, branch["rate_a"])
    else
        constraint_thermal_limit_to_repl(pm, nw, ne_br_idx, t_idx, branch["rate_a"])
    end
end


#### Constraint templates used in radial networks ####

"States that at most one of the ne_branches sharing the same bus pair must be built."
function constraint_branch_complementarity(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]

    constraint_branch_complementarity(pm, nw, br_idx, f_bus, t_bus)
end

""
function constraint_power_losses_on_off(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_power_losses_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

""
function constraint_power_losses_frb_on_off(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    tm = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_power_losses_frb_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

""
function constraint_power_losses_oltc_on_off(pm::_PM.AbstractBFModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    constraint_power_losses_oltc_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, vad_min, vad_max)
end

""
function constraint_ne_power_losses_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus = ne_branch["f_bus"]
    t_bus = ne_branch["t_bus"]
    f_idx = (ne_br_idx, f_bus, t_bus)
    t_idx = (ne_br_idx, t_bus, f_bus)
    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    ne_r       = ne_branch["br_r"]
    ne_x       = ne_branch["br_x"]
    ne_tm      = ne_branch["tap"]
    ne_g_sh_fr = ne_branch["g_fr"]
    ne_g_sh_to = ne_branch["g_to"]
    ne_b_sh_fr = ne_branch["b_fr"]
    ne_b_sh_to = ne_branch["b_to"]

    br_idx  = branch_idx(pm, nw, f_bus, t_bus)
    branch  = _PM.ref(pm, nw, :branch, br_idx)
    r       = branch["br_r"]
    x       = branch["br_x"]
    tm      = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    if ne_tm != tm
        Memento.error(_LOGGER, "ne_branch $(ne_br_idx) cannot be built in parallel to branch $(br_idx) because has a different tap ratio")
    end

    constraint_ne_power_losses_parallel(pm, nw, br_idx, ne_br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, ne_r, ne_x, ne_g_sh_fr, ne_g_sh_to, ne_b_sh_fr, ne_b_sh_to, tm, vad_min, vad_max)
end

""
function constraint_ne_power_losses_frb_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus = ne_branch["f_bus"]
    t_bus = ne_branch["t_bus"]
    f_idx = (ne_br_idx, f_bus, t_bus)
    t_idx = (ne_br_idx, t_bus, f_bus)
    vad_min = _PM.ref(pm, nw, :off_angmin)
    vad_max = _PM.ref(pm, nw, :off_angmax)

    ne_r       = ne_branch["br_r"]
    ne_x       = ne_branch["br_x"]
    ne_tm      = ne_branch["tap"]
    ne_g_sh_fr = ne_branch["g_fr"]
    ne_g_sh_to = ne_branch["g_to"]
    ne_b_sh_fr = ne_branch["b_fr"]
    ne_b_sh_to = ne_branch["b_to"]

    br_idx  = branch_idx(pm, nw, f_bus, t_bus)
    branch  = _PM.ref(pm, nw, :branch, br_idx)
    r       = branch["br_r"]
    x       = branch["br_x"]
    tm      = branch["tap"]
    g_sh_fr = branch["g_fr"]
    g_sh_to = branch["g_to"]
    b_sh_fr = branch["b_fr"]
    b_sh_to = branch["b_to"]

    if ne_tm != tm
        Memento.error(_LOGGER, "ne_branch $(ne_br_idx) cannot be built in parallel to branch $(br_idx) because has a different tap ratio")
    end

    constraint_ne_power_losses_frb_parallel(pm, nw, br_idx, ne_br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, ne_r, ne_x, ne_g_sh_fr, ne_g_sh_to, ne_b_sh_fr, ne_b_sh_to, tm, vad_min, vad_max)
end

""
function constraint_voltage_magnitude_difference_on_off(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_voltage_magnitude_difference_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end

""
function constraint_voltage_magnitude_difference_frb_on_off(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm = branch["tap"]

    constraint_voltage_magnitude_difference_frb_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
end

""
function constraint_voltage_magnitude_difference_oltc_on_off(pm::_PM.AbstractBFModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    f_idx = (br_idx, f_bus, t_bus)
    t_idx = (br_idx, t_bus, f_bus)

    r = branch["br_r"]
    x = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm_min = branch["tm_min"]
    tm_max = branch["tm_max"]

    constraint_voltage_magnitude_difference_oltc_on_off(pm, nw, br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm_min, tm_max)
end

""
function constraint_ne_voltage_magnitude_difference_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus = ne_branch["f_bus"]
    t_bus = ne_branch["t_bus"]
    f_idx = (ne_br_idx, f_bus, t_bus)
    t_idx = (ne_br_idx, t_bus, f_bus)

    ne_r       = ne_branch["br_r"]
    ne_x       = ne_branch["br_x"]
    ne_g_sh_fr = ne_branch["g_fr"]
    ne_b_sh_fr = ne_branch["b_fr"]
    ne_tm      = ne_branch["tap"]

    br_idx  = branch_idx(pm, nw, f_bus, t_bus)
    branch  = _PM.ref(pm, nw, :branch, br_idx)
    r       = branch["br_r"]
    x       = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm      = branch["tap"]

    if is_oltc_branch(pm, br_idx)
        Memento.error(_LOGGER, "ne_branch $ne_br_idx cannot be built in parallel to an OLTC (branch $br_idx)")
    end
    if ne_tm != tm
        Memento.error(_LOGGER, "ne_branch $ne_br_idx cannot be built in parallel to branch $br_idx because has a different tap ratio")
    end

    constraint_ne_voltage_magnitude_difference_parallel(pm, nw, br_idx, ne_br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, ne_r, ne_x, ne_g_sh_fr, ne_b_sh_fr, tm)
end

""
function constraint_ne_voltage_magnitude_difference_frb_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus = ne_branch["f_bus"]
    t_bus = ne_branch["t_bus"]
    f_idx = (ne_br_idx, f_bus, t_bus)
    t_idx = (ne_br_idx, t_bus, f_bus)

    ne_r       = ne_branch["br_r"]
    ne_x       = ne_branch["br_x"]
    ne_g_sh_fr = ne_branch["g_fr"]
    ne_b_sh_fr = ne_branch["b_fr"]
    ne_tm      = ne_branch["tap"]

    br_idx  = branch_idx(pm, nw, f_bus, t_bus)
    branch  = _PM.ref(pm, nw, :branch, br_idx)
    r       = branch["br_r"]
    x       = branch["br_x"]
    g_sh_fr = branch["g_fr"]
    b_sh_fr = branch["b_fr"]
    tm      = branch["tap"]

    if is_oltc_branch(pm, br_idx)
        Memento.error(_LOGGER, "ne_branch $ne_br_idx cannot be built in parallel to an OLTC (branch $br_idx)")
    end
    if ne_tm != tm
        Memento.error(_LOGGER, "ne_branch $ne_br_idx cannot be built in parallel to branch $br_idx because has a different tap ratio")
    end

    constraint_ne_voltage_magnitude_difference_frb_parallel(pm, nw, br_idx, ne_br_idx, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, ne_r, ne_x, ne_g_sh_fr, ne_b_sh_fr, tm)
end

""
function constraint_ne_thermal_limit_from_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus     = ne_branch["f_bus"]
    t_bus     = ne_branch["t_bus"]
    f_idx     = (ne_br_idx, f_bus, t_bus)
    if !haskey(ne_branch, "rate_a")
        Memento.error(_LOGGER, "constraint_ne_thermal_limit_from_parallel requires a rate_a value on all ne_branches, calc_thermal_limits! can be used to generate reasonable values")
    end
    ne_rate_a = ne_branch["rate_a"]

    br_idx = branch_idx(pm, nw, f_bus, t_bus)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    rate_a = branch["rate_a"]

    constraint_ne_thermal_limit_from_parallel(pm, nw, br_idx, ne_br_idx, f_idx, rate_a, ne_rate_a)
end

""
function constraint_ne_thermal_limit_to_parallel(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    f_bus     = ne_branch["f_bus"]
    t_bus     = ne_branch["t_bus"]
    t_idx     = (ne_br_idx, t_bus, f_bus)
    if !haskey(ne_branch, "rate_a")
        Memento.error(_LOGGER, "constraint_ne_thermal_limit_to_parallel requires a rate_a value on all ne_branches, calc_thermal_limits! can be used to generate reasonable values")
    end
    ne_rate_a = ne_branch["rate_a"]

    br_idx = branch_idx(pm, nw, f_bus, t_bus)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    rate_a = branch["rate_a"]

    constraint_ne_thermal_limit_to_parallel(pm, nw, br_idx, ne_br_idx, t_idx, rate_a, ne_rate_a)
end



### Actual constraints ###

function constraint_ohms_yt_from_repl(pm::_PM.AbstractDCPModel, n::Int, ne_br_idx, f_bus, t_bus, f_idx, b, vad_min, vad_max)
    p_fr  = _PM.var(pm, n,   :p, f_idx)
    va_fr = _PM.var(pm, n,   :va, f_bus)
    va_to = _PM.var(pm, n,   :va, t_bus)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, p_fr <= -b*(va_fr - va_to + vad_max*z))
    JuMP.@constraint(pm.model, p_fr >= -b*(va_fr - va_to + vad_min*z))
end

"nothing to do, this model is symetric"
function constraint_ohms_yt_to_repl(pm::_PM.AbstractAPLossLessModels, n::Int, ne_br_idx, f_bus, t_bus, t_idx, b, vad_min, vad_max)
end

function constraint_voltage_angle_difference_repl(pm::_PM.AbstractDCPModel, n::Int, ne_br_idx, f_idx, angmin, angmax, vad_min, vad_max)
    i, f_bus, t_bus = f_idx

    va_fr = _PM.var(pm, n, :va, f_bus)
    va_to = _PM.var(pm, n, :va, t_bus)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*(1-z) + vad_max*z)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*(1-z) + vad_min*z)
end

""
function constraint_thermal_limit_from_repl(pm::_PM.AbstractActivePowerModel, n::Int, ne_br_idx, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p, f_idx)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, p_fr <=  rate_a*(1-z))
    JuMP.@constraint(pm.model, p_fr >= -rate_a*(1-z))
end

""
function constraint_thermal_limit_to_repl(pm::_PM.AbstractActivePowerModel, n::Int, ne_br_idx, t_idx, rate_a)
    p_to = _PM.var(pm, n, :p, t_idx)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, p_to <=  rate_a*(1-z))
    JuMP.@constraint(pm.model, p_to >= -rate_a*(1-z))
end


#### Actual constraints used in radial networks ####

"States that at most one of the ne_branches sharing the same bus pair must be built."
function constraint_branch_complementarity(pm::_PM.AbstractPowerModel, n::Int, i, f_bus, t_bus)
    JuMP.@constraint(pm.model, sum(_PM.var(pm, n, :branch_ne, l) for l in ne_branch_ids(pm, n, f_bus, t_bus)) <= 1)
end

""
function constraint_voltage_magnitude_difference_on_off(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    branch = _PM.ref(pm, n, :branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  fr_bus["vmax"]^2/tm^2 - to_bus["vmin"]^2
    M_lo   = -fr_bus["vmin"]^2/tm^2 + to_bus["vmax"]^2
    
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    w_fr = _PM.var(pm, n, :w, f_bus)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :z_branch, i)

    JuMP.@constraint(pm.model, (w_fr/tm^2) - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, (w_fr/tm^2) - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end

""
function constraint_voltage_magnitude_difference_frb_on_off(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    branch = _PM.ref(pm, n, :branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  1.0^2/tm^2 - to_bus["vmin"]^2
    M_lo   = -1.0^2/tm^2 + to_bus["vmax"]^2
    
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :z_branch, i)
    # w_fr is assumed equal to 1.0

    JuMP.@constraint(pm.model, (1.0/tm^2) - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, (1.0/tm^2) - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end

""
function constraint_voltage_magnitude_difference_oltc_on_off(pm::_PM.AbstractBFAModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm_min, tm_max)
    branch = _PM.ref(pm, n, :branch, i)
    fr_bus = _PM.ref(pm, n, :bus, f_bus)
    to_bus = _PM.ref(pm, n, :bus, t_bus)
    M_hi   =  1.0^2/tm_min^2 - to_bus["vmin"]^2
    M_lo   = -1.0^2/tm_max^2 + to_bus["vmax"]^2
    
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    ttmi = _PM.var(pm, n, :ttmi, i)
    w_to = _PM.var(pm, n, :w, t_bus)
    z    = _PM.var(pm, n, :z_branch, i)
    # w_fr is assumed equal to 1.0 to preserve the linearity of the model

    JuMP.@constraint(pm.model, 1.0*ttmi - w_to <= 2*(r*p_fr + x*q_fr) + M_hi*(1-z) )
    JuMP.@constraint(pm.model, 1.0*ttmi - w_to >= 2*(r*p_fr + x*q_fr) - M_lo*(1-z) )
end

""
function constraint_ne_voltage_magnitude_difference_parallel(pm::_PM.AbstractBFAModel, n::Int, br_idx_e, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_e, x_e, g_sh_fr_e, b_sh_fr_e, r_c, x_c, g_sh_fr_c, b_sh_fr_c, tm)
    # Suffixes: _e: existing branch; _c: candidate branch; _p: parallel equivalent
    r_p  = (r_e*(r_c^2+x_c^2)+r_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)
    x_p  = (x_e*(r_c^2+x_c^2)+x_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)

    constraint_ne_voltage_magnitude_difference(pm::_PM.AbstractBFAModel, n::Int, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_p, x_p, 0, 0, tm)
end

""
function constraint_ne_voltage_magnitude_difference_frb_parallel(pm::_PM.AbstractBFAModel, n::Int, br_idx_e, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_e, x_e, g_sh_fr_e, b_sh_fr_e, r_c, x_c, g_sh_fr_c, b_sh_fr_c, tm)
    # Suffixes: _e: existing branch; _c: candidate branch; _p: parallel equivalent
    r_p  = (r_e*(r_c^2+x_c^2)+r_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)
    x_p  = (x_e*(r_c^2+x_c^2)+x_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)

    constraint_ne_voltage_magnitude_difference_frb(pm::_PM.AbstractBFAModel, n::Int, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_p, x_p, 0, 0, tm)
end



## Auxiliary functions ##

function replace_branch(pm, nw, f_bus, t_bus)
    replace = 0
    ne_br_idx = 0
    for (br, ne_branch) in _PM.ref(pm, nw, :ne_branch)
        if ((ne_branch["f_bus"] == f_bus && ne_branch["t_bus"] == t_bus) || (ne_branch["f_bus"] == t_bus && ne_branch["t_bus"] == f_bus)) && ne_branch["replace"] == true
            replace = 1
            ne_br_idx = br
        end
    end
    return replace, ne_br_idx
end

"Returns the index of `branch` connecting `f_bus` to `t_bus`, if such a `branch` exists; 0 otherwise"
function branch_idx(pm::_PM.AbstractPowerModel, nw::Int, f_bus, t_bus)
    buspairs = _PM.ref(pm, nw, :buspairs)
    buspair = get(buspairs, (f_bus,t_bus), Dict("branch"=>0))
    return buspair["branch"]
end

"Returns a list of indices of `ne_branch`es relative to `branch` `br_idx`"
function ne_branch_ids(pm::_PM.AbstractPowerModel, br_idx::Int; nw::Int=pm.cnw)
    branch = _PM.ref(pm, nw, :branch, br_idx)
    f_bus = branch["f_bus"]
    t_bus = branch["t_bus"]
    ne_branch_ids(pm, nw, f_bus, t_bus)
end

"Returns a list of indices of `ne_branch`es connecting `f_bus` to `t_bus`"
function ne_branch_ids(pm::_PM.AbstractPowerModel, nw::Int, f_bus, t_bus)
    ne_buspairs = _PM.ref(pm, nw, :ne_buspairs)
    ne_buspair = get(ne_buspairs, (f_bus,t_bus), Dict("branches"=>Int[]))
    return ne_buspair["branches"]
end

"Returns whether a `ne_branch` is intended to replace the existing branch or to be added in parallel"
function ne_branch_replace(pm::_PM.AbstractPowerModel, ne_br_idx::Int; nw::Int=pm.cnw)
    ne_branch = _PM.ref(pm, nw, :ne_branch, ne_br_idx)
    if !haskey(ne_branch, "replace")
        Memento.error(_LOGGER, "a `replace` value is required on all `ne_branch`es")
    end
    return ne_branch["replace"] == 1
end
