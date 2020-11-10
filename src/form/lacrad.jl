# Linearized AC form for radial networks.
# Variables: squared voltage magnitude, active power, reactive power.

using LinearAlgebra: pinv

""
function _PM.variable_bus_voltage(pm::LACRadPowerModel; kwargs...)
    _PM.variable_bus_voltage_magnitude_sqr(pm; kwargs...)
end

""
function _PM.variable_bus_voltage_magnitude_only(pm::LACRadPowerModel; kwargs...)
    _PM.variable_bus_voltage_magnitude_sqr(pm; kwargs...)
end

"nothing to add, there are no voltage variables on branches"
function _PM.variable_ne_branch_voltage(pm::LACRadPowerModel; kwargs...)
end

"Do nothing, no way to represent this in these variables"
function _PM.constraint_theta_ref(pm::LACRadPowerModel, n::Int, ref_bus::Int)
end

# Copied from constraint_power_balance(pm::AbstractWModels, n::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
# in PowerModels/src/form/shared.jl, because AbstractWModels is a type union and cannot be subtyped
""
function _PM.constraint_power_balance(pm::LACRadPowerModel, n::Int, i, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, :w, i)
    p    = get(var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")


    cstr_p = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*w
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*w
    )

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

# Copied from constraint_ne_power_balance(pm::AbstractWModels, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
# in PowerModels/src/form/shared.jl, because AbstractWModels is a type union and cannot be subtyped
""
function _PM.constraint_ne_power_balance(pm::LACRadPowerModel, n::Int, i::Int, bus_arcs, bus_arcs_dc, bus_arcs_sw, bus_arcs_ne, bus_gens, bus_storage, bus_pd, bus_qd, bus_gs, bus_bs)
    w    = var(pm, n, :w, i)
    p    = get(var(pm, n),    :p, Dict()); _check_var_keys(p, bus_arcs, "active power", "branch")
    q    = get(var(pm, n),    :q, Dict()); _check_var_keys(q, bus_arcs, "reactive power", "branch")
    pg   = get(var(pm, n),   :pg, Dict()); _check_var_keys(pg, bus_gens, "active power", "generator")
    qg   = get(var(pm, n),   :qg, Dict()); _check_var_keys(qg, bus_gens, "reactive power", "generator")
    ps   = get(var(pm, n),   :ps, Dict()); _check_var_keys(ps, bus_storage, "active power", "storage")
    qs   = get(var(pm, n),   :qs, Dict()); _check_var_keys(qs, bus_storage, "reactive power", "storage")
    psw  = get(var(pm, n),  :psw, Dict()); _check_var_keys(psw, bus_arcs_sw, "active power", "switch")
    qsw  = get(var(pm, n),  :qsw, Dict()); _check_var_keys(qsw, bus_arcs_sw, "reactive power", "switch")
    p_dc = get(var(pm, n), :p_dc, Dict()); _check_var_keys(p_dc, bus_arcs_dc, "active power", "dcline")
    q_dc = get(var(pm, n), :q_dc, Dict()); _check_var_keys(q_dc, bus_arcs_dc, "reactive power", "dcline")
    p_ne = get(var(pm, n), :p_ne, Dict()); _check_var_keys(p_ne, bus_arcs_ne, "active power", "ne_branch")
    q_ne = get(var(pm, n), :q_ne, Dict()); _check_var_keys(q_ne, bus_arcs_ne, "reactive power", "ne_branch")


    cstr_p = JuMP.@constraint(pm.model,
        sum(p[a] for a in bus_arcs)
        + sum(p_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(psw[a_sw] for a_sw in bus_arcs_sw)
        + sum(p_ne[a] for a in bus_arcs_ne)
        ==
        sum(pg[g] for g in bus_gens)
        - sum(ps[s] for s in bus_storage)
        - sum(pd for pd in values(bus_pd))
        - sum(gs for gs in values(bus_gs))*w
    )
    cstr_q = JuMP.@constraint(pm.model,
        sum(q[a] for a in bus_arcs)
        + sum(q_dc[a_dc] for a_dc in bus_arcs_dc)
        + sum(qsw[a_sw] for a_sw in bus_arcs_sw)
        + sum(q_ne[a] for a in bus_arcs_ne)
        ==
        sum(qg[g] for g in bus_gens)
        - sum(qs[s] for s in bus_storage)
        - sum(qd for qd in values(bus_qd))
        + sum(bs for bs in values(bus_bs))*w
    )

    if _IM.report_duals(pm)
        sol(pm, n, :bus, i)[:lam_kcl_r] = cstr_p
        sol(pm, n, :bus, i)[:lam_kcl_i] = cstr_q
    end
end

""
function _PM.constraint_ohms_yt_from(pm::LACRadPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    z    = pinv(g + im * b)
    r, x = real(z), imag(z)

    JuMP.@constraint(pm.model, 2*r*p_fr + 2*x*q_fr ==  w_fr/tm^2 - w_to )
end

""
function _PM.constraint_ohms_yt_to(pm::LACRadPowerModel, n::Int, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    p_to = var(pm, n, :p, t_idx)
    q_to = var(pm, n, :q, t_idx)

    JuMP.@constraint(pm.model, p_to  ==  - p_fr )
    JuMP.@constraint(pm.model, q_to  ==  - q_fr )
end

""
function _PM.constraint_ne_ohms_yt_from(pm::LACRadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_fr, b_fr, tr, ti, tm, vad_min, vad_max)
        p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    z    = pinv(g + im * b)
    r, x = real(z), imag(z)

    JuMP.@constraint(pm.model, 2*r*p_fr + 2*x*q_fr ==  w_fr/tm^2 - w_to )
end

""
function _PM.constraint_ne_ohms_yt_to(pm::LACRadPowerModel, n::Int, i, f_bus, t_bus, f_idx, t_idx, g, b, g_to, b_to, tr, ti, tm, vad_min, vad_max)
    p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    p_to = var(pm, n, :p_ne, t_idx)
    q_to = var(pm, n, :q_ne, t_idx)

    JuMP.@constraint(pm.model, p_to  ==  - p_fr )
    JuMP.@constraint(pm.model, q_to  ==  - q_fr )
end

"nothing to do, no voltage angle variables"
function _PM.constraint_voltage_angle_difference(pm::LACRadPowerModel, n::Int, f_idx, angmin, angmax)
end

"nothing to do, no voltage angle variables"
function _PM.constraint_ne_voltage_angle_difference(pm::LACRadPowerModel, n::Int, f_idx, angmin, angmax, vad_min, vad_max)
end

"octagonal approximation of apparent power"
function _PM.constraint_thermal_limit_from(pm::LACRadPowerModel, n::Int, f_idx, rate_a)
    p_fr = var(pm, n, :p, f_idx)
    q_fr = var(pm, n, :q, f_idx)
    sqrt2 = sqrt(2)

    JuMP.@constraint(pm.model, p_fr <=  rate_a)
    JuMP.@constraint(pm.model, p_fr >= -rate_a)
    JuMP.@constraint(pm.model, q_fr <=  rate_a)
    JuMP.@constraint(pm.model, q_fr >= -rate_a)
    JuMP.@constraint(pm.model, p_fr + q_fr <=  sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr + q_fr >= -sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr - q_fr <=  sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr - q_fr >= -sqrt2*rate_a)
end

"nothing to do, no line losses in this model"
function _PM.constraint_thermal_limit_to(pm::LACRadPowerModel, n::Int, t_idx, rate_a)
end

"octagonal approximation of apparent power"
function _PM.constraint_ne_thermal_limit_from(pm::LACRadPowerModel, n::Int, f_idx, rate_a)
    p_fr = var(pm, n, :p_ne, f_idx)
    q_fr = var(pm, n, :q_ne, f_idx)
    sqrt2 = sqrt(2)

    JuMP.@constraint(pm.model, p_fr <=  rate_a)
    JuMP.@constraint(pm.model, p_fr >= -rate_a)
    JuMP.@constraint(pm.model, q_fr <=  rate_a)
    JuMP.@constraint(pm.model, q_fr >= -rate_a)
    JuMP.@constraint(pm.model, p_fr + q_fr <=  sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr + q_fr >= -sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr - q_fr <=  sqrt2*rate_a)
    JuMP.@constraint(pm.model, p_fr - q_fr >= -sqrt2*rate_a)
end

"nothing to do, no line losses in this model"
function _PM.constraint_ne_thermal_limit_to(pm::LACRadPowerModel, n::Int, t_idx, rate_a)
end

# Copied from constraint_switch_state_closed(pm::AbstractWModels, n::Int, f_bus, t_bus) in
# PowerModels/src/form/shared.jl, because AbstractWModels is a type union and cannot be subtyped
""
function _PM.constraint_switch_state_closed(pm::LACRadPowerModel, n::Int, f_bus, t_bus)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)

    JuMP.@constraint(pm.model, w_fr == w_to)
end

# Copied from constraint_switch_voltage_on_off(pm::AbstractWModels, n::Int, i, f_bus, t_bus, vad_min, vad_max)
# in PowerModels/src/form/shared.jl, because AbstractWModels is a type union and cannot be subtyped
""
function _PM.constraint_switch_voltage_on_off(pm::LACRadPowerModel, n::Int, i, f_bus, t_bus, vad_min, vad_max)
    w_fr = var(pm, n, :w, f_bus)
    w_to = var(pm, n, :w, t_bus)
    z = var(pm, n, :z_switch, i)

    w_fr_lb, w_fr_ub = _IM.variable_domain(w_fr)
    w_to_lb, w_to_ub = _IM.variable_domain(w_to)

    @assert w_fr_lb >= 0.0 && w_to_lb >= 0.0

    off_ub = w_fr_ub - w_to_lb
    off_lb = w_fr_lb - w_to_ub

    JuMP.@constraint(pm.model, 0.0 <= (w_fr - w_to) + off_ub*(1-z))
    JuMP.@constraint(pm.model, 0.0 >= (w_fr - w_to) + off_lb*(1-z))
end

"""
Convert the solution data into the data model's standard space, polar voltages and rectangular power.

Bus voltage magnitude `vm` is the square root of `w`.
Bus voltage angle `va` is that of the reference bus.
"""
function _PM.sol_data_model!(pm::LACRadPowerModel, solution::Dict)
    if haskey(solution, "nw")
        nws_data = solution["nw"]
        nws_pmdata = pm.data["nw"]
    else
        nws_data = Dict("0" => solution)
        nws_pmdata = Dict("0" => pm.data)
    end

    for (n, nw_data) in nws_data
        if haskey(nw_data, "bus")
            ref_va = NaN
            for (i,bus) in nws_pmdata[n]["bus"]
                if bus["bus_type"] == 3
                    ref_va = bus["va"]
                    break
                end
            end
            if ref_va == NaN
                Memento.warn(_LOGGER, "no reference bus found, setting voltage angle to 0 for all buses")
                ref_va = 0.0
            end

            for (i,bus) in nw_data["bus"]
                if haskey(bus, "w")
                    bus["vm"] = sqrt(bus["w"])
                    delete!(bus, "w")
                end
                bus["va"] = ref_va
            end
        end
    end
end
