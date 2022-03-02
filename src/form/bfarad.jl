# Linearized AC branch flow model for radial networks.
# Variables: squared voltage magnitude, active power, reactive power.



## Variables

""
function _PM.variable_bus_voltage(pm::BFARadPowerModel; kwargs...)
    _PM.variable_bus_voltage_magnitude_sqr(pm; kwargs...)
    _PM.variable_bus_voltage_angle(pm; kwargs...)
end

"Voltage angle of all buses is that of the reference bus"
function _PM.variable_bus_voltage_angle(pm::BFARadPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    report && _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :bus, :va, _PM.ids(pm, nw, :bus), last(first(_PM.ref(pm,nw,:ref_buses)))["va"])
end

# Copied from _PM.variable_branch_power_real(pm::AbstractAPLossLessModels; nw::Int, bounded::Bool, report::Bool)
# Since this model is lossless, active power variables are 1 per branch instead of 2.
""
function _PM.variable_branch_power_real(pm::BFARadPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    p = _PM.var(pm, nw)[:p] = JuMP.@variable(pm.model,
        [(l,i,j) in _PM.ref(pm, nw, :arcs_from)], base_name="$(nw)_p",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "p_start")
    )

    if bounded
        flow_lb, flow_ub = _PM.ref_calc_branch_flow_bounds(_PM.ref(pm, nw, :branch), _PM.ref(pm, nw, :bus))

        for arc in _PM.ref(pm, nw, :arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(p[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(p[arc], flow_ub[l])
            end
        end
    end

    for (l,branch) in _PM.ref(pm, nw, :branch)
        if haskey(branch, "pf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(p[f_idx], branch["pf_start"])
        end
    end

    # this explicit type erasure is necessary
    p_expr = Dict{Any,Any}( ((l,i,j), p[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :arcs_from) )
    p_expr = merge(p_expr, Dict( ((l,j,i), -1.0*p[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :arcs_from)))
    _PM.var(pm, nw)[:p] = p_expr

    report && _IM.sol_component_value_edge(pm, _PM.pm_it_sym, nw, :branch, :pf, :pt, _PM.ref(pm, nw, :arcs_from), _PM.ref(pm, nw, :arcs_to), p_expr)
end

# Copied from _PM.variable_ne_branch_power_real(pm::AbstractAPLossLessModels; nw::Int, bounded::Bool, report::Bool)
# and improved by comparing with _PM.variable_branch_power_real(pm::AbstractAPLossLessModels; nw::Int, bounded::Bool, report::Bool).
# Since this model is lossless, active power variables are 1 per branch instead of 2.
""
function _PM.variable_ne_branch_power_real(pm::BFARadPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    p_ne = _PM.var(pm, nw)[:p_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in _PM.ref(pm, nw, :ne_arcs_from)], base_name="$(nw)_p_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_branch, l), "p_start")
    )

    if bounded
        flow_lb, flow_ub = _PM.ref_calc_branch_flow_bounds(_PM.ref(pm, nw, :ne_branch), _PM.ref(pm, nw, :bus))

        for arc in _PM.ref(pm, nw, :ne_arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(p_ne[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(p_ne[arc], flow_ub[l])
            end
        end
    end

    # this explicit type erasure is necessary
    p_ne_expr = Dict{Any,Any}( ((l,i,j), p_ne[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :ne_arcs_from) )
    p_ne_expr = merge(p_ne_expr, Dict(((l,j,i), -1.0*p_ne[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :ne_arcs_from)))
    _PM.var(pm, nw)[:p_ne] = p_ne_expr

    report && _IM.sol_component_value_edge(pm, _PM.pm_it_sym, nw, :ne_branch, :pf, :pt, _PM.ref(pm, nw, :ne_arcs_from), _PM.ref(pm, nw, :ne_arcs_to), p_ne_expr)
end

# Adapted from variable_branch_power_real(pm::BFARadPowerModel; nw::Int, bounded::Bool, report::Bool)
""
function _PM.variable_branch_power_imaginary(pm::BFARadPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    q = _PM.var(pm, nw)[:q] = JuMP.@variable(pm.model,
        [(l,i,j) in _PM.ref(pm, nw, :arcs_from)], base_name="$(nw)_q",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :branch, l), "q_start")
    )

    if bounded
        flow_lb, flow_ub = _PM.ref_calc_branch_flow_bounds(_PM.ref(pm, nw, :branch), _PM.ref(pm, nw, :bus))

        for arc in _PM.ref(pm, nw, :arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(q[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(q[arc], flow_ub[l])
            end
        end
    end

    for (l,branch) in _PM.ref(pm, nw, :branch)
        if haskey(branch, "qf_start")
            f_idx = (l, branch["f_bus"], branch["t_bus"])
            JuMP.set_start_value(q[f_idx], branch["qf_start"])
        end
    end

    # this explicit type erasure is necessary
    q_expr = Dict{Any,Any}( ((l,i,j), q[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :arcs_from) )
    q_expr = merge(q_expr, Dict( ((l,j,i), -1.0*q[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :arcs_from)))
    _PM.var(pm, nw)[:q] = q_expr

    report && _IM.sol_component_value_edge(pm, _PM.pm_it_sym, nw, :branch, :qf, :qt, _PM.ref(pm, nw, :arcs_from), _PM.ref(pm, nw, :arcs_to), q_expr)
end

# Adapted from variable_ne_branch_power_real(pm::BFARadPowerModel; nw::Int, bounded::Bool, report::Bool)
""
function _PM.variable_ne_branch_power_imaginary(pm::BFARadPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    q_ne = _PM.var(pm, nw)[:q_ne] = JuMP.@variable(pm.model,
        [(l,i,j) in _PM.ref(pm, nw, :ne_arcs_from)], base_name="$(nw)_q_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_branch, l), "q_start")
    )

    if bounded
        flow_lb, flow_ub = _PM.ref_calc_branch_flow_bounds(_PM.ref(pm, nw, :ne_branch), _PM.ref(pm, nw, :bus))

        for arc in _PM.ref(pm, nw, :ne_arcs_from)
            l,i,j = arc
            if !isinf(flow_lb[l])
                JuMP.set_lower_bound(q_ne[arc], flow_lb[l])
            end
            if !isinf(flow_ub[l])
                JuMP.set_upper_bound(q_ne[arc], flow_ub[l])
            end
        end
    end

    # this explicit type erasure is necessary
    q_ne_expr = Dict{Any,Any}( ((l,i,j), q_ne[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :ne_arcs_from) )
    q_ne_expr = merge(q_ne_expr, Dict(((l,j,i), -1.0*q_ne[(l,i,j)]) for (l,i,j) in _PM.ref(pm, nw, :ne_arcs_from)))
    _PM.var(pm, nw)[:q_ne] = q_ne_expr

    report && _IM.sol_component_value_edge(pm, _PM.pm_it_sym, nw, :ne_branch, :qf, :qt, _PM.ref(pm, nw, :ne_arcs_from), _PM.ref(pm, nw, :ne_arcs_to), q_ne_expr)
end



## Constraints

"Nothing to do, this model is lossless"
function _PM.constraint_power_losses(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end

"Nothing to do, this model is lossless"
function constraint_power_losses_on_off(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_power_losses_frb(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm)
end

"Nothing to do, this model is lossless"
function constraint_power_losses_frb_on_off(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_power_losses_oltc(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to)
end

"Nothing to do, this model is lossless"
function constraint_power_losses_oltc_on_off(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_ne_power_losses(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_ne_power_losses_parallel(pm::BFARadPowerModel, n::Int, br_idx_e, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_e, x_e, g_sh_fr_e, g_sh_to_e, b_sh_fr_e, b_sh_to_e, r_c, x_c, g_sh_fr_c, g_sh_to_c, b_sh_fr_c, b_sh_to_c, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_ne_power_losses_frb(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_ne_power_losses_frb_parallel(pm::BFARadPowerModel, n::Int, br_idx_e, br_idx_c, f_bus, t_bus, f_idx_c, t_idx_c, r_e, x_e, g_sh_fr_e, g_sh_to_e, b_sh_fr_e, b_sh_to_e, r_c, x_c, g_sh_fr_c, g_sh_to_c, b_sh_fr_c, b_sh_to_c, tm, vad_min, vad_max)
end

"Nothing to do, this model is lossless"
function constraint_ne_power_losses_oltc(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, g_sh_to, b_sh_fr, b_sh_to, vad_min, vad_max)
end

"Nothing to do, no voltage angle variables"
function _PM.constraint_voltage_angle_difference(pm::BFARadPowerModel, n::Int, f_idx, angmin, angmax)
end

"Nothing to do, no voltage angle variables"
function _PM.constraint_voltage_angle_difference_on_off(pm::BFARadPowerModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
end

"Nothing to do, no voltage angle variables"
function _PM.constraint_ne_voltage_angle_difference(pm::BFARadPowerModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
end

"Defines voltage drop over a branch whose `f_bus` is the reference bus"
function constraint_voltage_magnitude_difference_frb(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr, tm)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    w_to = _PM.var(pm, n, :w, t_bus)
    # w_fr is assumed equal to 1.0

    JuMP.@constraint(pm.model, (1.0/tm^2) - w_to ==  2*(r*p_fr + x*q_fr))
end

"Defines voltage drop over a transformer branch that has an OLTC"
function constraint_voltage_magnitude_difference_oltc(pm::BFARadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, r, x, g_sh_fr, b_sh_fr)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    ttmi = _PM.var(pm, n, :ttmi, i)
    w_to = _PM.var(pm, n, :w, t_bus)
    # w_fr is assumed equal to 1.0 to preserve the linearity of the model

    JuMP.@constraint(pm.model, 1.0*ttmi - w_to == 2*(r*p_fr + x*q_fr))
end

"Complex power is limited by an octagon instead of a circle, so as to keep the model linear"
function _PM.constraint_thermal_limit_from(pm::BFARadPowerModel, n::Int, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    c_perp = cos(π/8) # ~0.92
    c_diag = sin(π/8) + cos(π/8) # == cos(π/8) * sqrt(2), ~1.31

    JuMP.@constraint(pm.model, -c_perp*rate_a <= p_fr        <= c_perp*rate_a)
    JuMP.@constraint(pm.model, -c_perp*rate_a <=        q_fr <= c_perp*rate_a)
    JuMP.@constraint(pm.model, -c_diag*rate_a <= p_fr + q_fr <= c_diag*rate_a)
    JuMP.@constraint(pm.model, -c_diag*rate_a <= p_fr - q_fr <= c_diag*rate_a)
end

"Complex power is limited by an octagon instead of a circle, so as to keep the model linear"
function _PM.constraint_thermal_limit_from_on_off(pm::BFARadPowerModel, n::Int, i, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p, f_idx)
    q_fr = _PM.var(pm, n, :q, f_idx)
    z    = _PM.var(pm, n, :z_branch, i)
    c_perp = cos(π/8) # ~0.92
    c_diag = sin(π/8) + cos(π/8) # == cos(π/8) * sqrt(2), ~1.31

    JuMP.@constraint(pm.model, p_fr        >= -c_perp*rate_a*z)
    JuMP.@constraint(pm.model, p_fr        <=  c_perp*rate_a*z)
    JuMP.@constraint(pm.model,        q_fr >= -c_perp*rate_a*z)
    JuMP.@constraint(pm.model,        q_fr <=  c_perp*rate_a*z)
    JuMP.@constraint(pm.model, p_fr + q_fr >= -c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr + q_fr <=  c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr - q_fr >= -c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr - q_fr <=  c_diag*rate_a*z)
end

"Complex power is limited by an octagon instead of a circle, so as to keep the model linear"
function _PM.constraint_ne_thermal_limit_from(pm::BFARadPowerModel, n::Int, i, f_idx, rate_a)
    p_fr = _PM.var(pm, n, :p_ne, f_idx)
    q_fr = _PM.var(pm, n, :q_ne, f_idx)
    z    = _PM.var(pm, n, :branch_ne, i)
    c_perp = cos(π/8) # ~0.92
    c_diag = sin(π/8) + cos(π/8) # == cos(π/8) * sqrt(2), ~1.31

    JuMP.@constraint(pm.model, p_fr        >= -c_perp*rate_a*z)
    JuMP.@constraint(pm.model, p_fr        <=  c_perp*rate_a*z)
    JuMP.@constraint(pm.model,        q_fr >= -c_perp*rate_a*z)
    JuMP.@constraint(pm.model,        q_fr <=  c_perp*rate_a*z)
    JuMP.@constraint(pm.model, p_fr + q_fr >= -c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr + q_fr <=  c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr - q_fr >= -c_diag*rate_a*z)
    JuMP.@constraint(pm.model, p_fr - q_fr <=  c_diag*rate_a*z)
end

""
function constraint_ne_thermal_limit_from_parallel(pm::BFARadPowerModel, n::Int, br_idx_e, br_idx_c, f_idx_c, rate_a_e, rate_a_c)
    # Suffixes: _e: existing branch; _c: candidate branch; _p: parallel equivalent
    branch_e = _PM.ref(pm, n, :branch, br_idx_e)
    branch_c = _PM.ref(pm, n, :ne_branch, br_idx_c)
    r_e      = branch_e["br_r"]
    r_c      = branch_c["br_r"]
    x_e      = branch_e["br_x"]
    x_c      = branch_c["br_x"]

    r_p      = (r_e*(r_c^2+x_c^2)+r_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)
    x_p      = (x_e*(r_c^2+x_c^2)+x_c*(r_e^2+x_e^2)) / ((r_e+r_c)^2+(x_e+x_c)^2)
    rate_a_p = min(rate_a_e*sqrt(r_e^2+x_e^2),rate_a_c*sqrt(r_c^2+x_c^2)) / sqrt(r_p^2+x_p^2)

    _PM.constraint_ne_thermal_limit_from(pm, n, br_idx_c, f_idx_c, rate_a_p)
end

"Nothing to do, this model is symmetric"
function _PM.constraint_thermal_limit_to(pm::BFARadPowerModel, n::Int, t_idx, rate_a)
end

"Nothing to do, this model is symmetric"
function _PM.constraint_thermal_limit_to_on_off(pm::BFARadPowerModel, n::Int, i, t_idx, rate_a)
end

"Nothing to do, this model is symmetric"
function _PM.constraint_ne_thermal_limit_to(pm::BFARadPowerModel, n::Int, i, t_idx, rate_a)
end

"Nothing to do, this model is symmetric"
function constraint_ne_thermal_limit_to_parallel(pm::BFARadPowerModel, n::Int, br_idx_e, br_idx_c, f_idx_c, rate_a_e, rate_a_c)
end


## Other functions

"""
Converts the solution data into the data model's standard space, polar voltages and rectangular power.

Bus voltage magnitude `vm` is the square root of `w`.
Voltage magnitude of the reference bus is 1.0 p.u.
Branch OLTC tap ratio `tm` (if applies) is the square root of the inverse of `ttmi`.
"""
function _PM.sol_data_model!(pm::BFARadPowerModel, solution::Dict)
    if haskey(solution["it"]["pm"], "nw")
        nws_sol = solution["it"]["pm"]["nw"]
    else
        nws_sol = Dict("0" => solution)
    end

    for (nw, nw_sol) in nws_sol

        # Find reference bus id
        n = parse(Int, nw)
        ref_buses = _PM.ref(pm, n, :ref_buses)
        if length(ref_buses) == 0
            Memento.error(_LOGGER, "no reference bus found")
        end
        if length(ref_buses) > 1
            Memento.error(_LOGGER, "networks with multiple reference buses are not supported")
        end
        ref_bus_id = first(keys(ref_buses))

        # Bus voltage magnitude `vm` is the square root of `w`
        for (i,bus) in nw_sol["bus"]
            if haskey(bus, "w")
                bus["vm"] = sqrt(bus["w"])
                delete!(bus, "w")
            end
        end

        # The voltage magnitude of the reference bus is 1.0 p.u.
        nw_sol["bus"]["$ref_bus_id"]["vm"] = 1.0

        # OLTC tap ratio `tm` of `branch`es (if applies) is the square root of the inverse of `ttmi`
        for (i,br) in nw_sol["branch"]
            if haskey(br, "ttmi")
                if haskey(nw_sol,"ne_branch") && any([nw_sol["ne_branch"]["$ne_br_id"]["built"] for ne_br_id in ne_branch_ids(pm, parse(Int,i), nw = n)] .== 1.0)
                    # if branch is not built
                    br["tm"] = 0.0
                else
                    br["tm"] = sqrt(1.0/br["ttmi"])
                end
                delete!(br, "ttmi")
            end
        end

        # OLTC tap ratio `tm` of `ne_branch`es (if applies) is the square root of the inverse of `ttmi`
        if haskey(nw_sol,"ne_branch")
            for (i,br) in nw_sol["ne_branch"]
                if haskey(br, "ttmi")
                    if br["built"] == 0.0
                        br["tm"] = 0.0
                    else
                        br["tm"] = sqrt(1.0/br["ttmi"])
                    end
                    delete!(br, "ttmi")
                end
            end
        end

    end
end
