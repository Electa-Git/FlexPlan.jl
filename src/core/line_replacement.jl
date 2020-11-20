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

#Actual constraints
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

    JuMP.@constraint(pm.model, va_fr - va_to <= angmax*z + vad_max*z)
    JuMP.@constraint(pm.model, va_fr - va_to >= angmin*z + vad_min*z)
end

""
function constraint_thermal_limit_from_repl(pm::_PM.AbstractActivePowerModel, n::Int, ne_br_idx, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p, f_idx)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, p_fr <=  rate_a*(1-z))
    JuMP.@constraint(pm.model, p_fr >= -rate_a*z)
end

""
function constraint_thermal_limit_to_repl(pm::_PM.AbstractActivePowerModel, n::Int, ne_br_idx, t_idx, rate_a)
    p_to = _PM.var(pm, n, :p, t_idx)
    z = _PM.var(pm, n, :branch_ne, ne_br_idx)

    JuMP.@constraint(pm.model, p_to <=  rate_a*(1-z))
    JuMP.@constraint(pm.model, p_to >= -rate_a*(1-z))
end


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