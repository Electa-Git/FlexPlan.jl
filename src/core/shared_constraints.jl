# Constraint template: Power balance constraint including candidate storage
function constraint_power_balance_acne_dcne_strg(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_arcs_dc = PowerModels.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = PowerModels.ref(pm, nw, :bus_convs_ac, i)
    bus_convs_ac_ne = PowerModels.ref(pm, nw, :bus_convs_ac_ne, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    constraint_power_balance_acne_dcne_strg(pm, nw, i, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end
#Power balance constraint including candidate storage
function constraint_power_balance_acne_dcne_strg(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne = _PM.var(pm, n, :pconv_ac_ne)
    p_ne = _PM.var(pm, n, :p_ne)
    ps   = _PM.var(pm, n, :ps)
    ps_ne   = _PM.var(pm, n, :ps_ne)
    v = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end

# Constraint template: Power balance constraint (without DC equipment) including candidate storage
function constraint_power_balance_acne_strg(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    constraint_power_balance_acne_strg(pm, nw, i, bus_arcs, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end
#Power balance constraint (without DC equipment) including candidate storage
function constraint_power_balance_acne_strg(pm::_PM.AbstractWModels, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p     = _PM.var(pm, n, :p)
    q     = _PM.var(pm, n, :q)
    p_ne  = _PM.var(pm, n, :p_ne)
    q_ne  = _PM.var(pm, n, :q_ne)
    pg    = _PM.var(pm, n, :pg)
    qg    = _PM.var(pm, n, :qg)
    ps    = _PM.var(pm, n, :ps)
    qs    = _PM.var(pm, n, :qs)
    ps_ne = _PM.var(pm, n, :ps_ne)
    qs_ne = _PM.var(pm, n, :qs_ne)
    w     = _PM.var(pm, n, :w, i)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(ps_ne[s] for s in bus_storage_ne) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*w)
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - sum(qs[s] for s in bus_storage) - sum(qs_ne[s] for s in bus_storage_ne) - sum(qd[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*w)
end

#Constraint template:  Power Balance constraint including candidate storage & flexible demand
function constraint_power_balance_acne_dcne_flex(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_arcs_dc = PowerModels.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = PowerModels.ref(pm, nw, :bus_convs_ac, i)
    bus_convs_ac_ne = PowerModels.ref(pm, nw, :bus_convs_ac_ne, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    constraint_power_balance_acne_dcne_flex(pm, nw, i, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end
# Power Balance constraint including candidate storage & flexible demand
function constraint_power_balance_acne_dcne_flex(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne = _PM.var(pm, n, :pconv_ac_ne)
    p_ne = _PM.var(pm, n, :p_ne)
    ps   = _PM.var(pm, n, :ps)
    ps_ne   = _PM.var(pm, n, :ps_ne)
    pflex = _PM.var(pm, n, :pflex)
    v = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end

#Constraint template:  Power Balance constraint (without DC equipment) including candidate storage & flexible demand
function constraint_power_balance_acne_flex(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    constraint_power_balance_acne_flex(pm, nw, i, bus_arcs, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end
# Power Balance constraint (without DC equipment) including candidate storage & flexible demand
function constraint_power_balance_acne_flex(pm::_PM.AbstractWModels, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p                = _PM.var(pm, n, :p)
    q                = _PM.var(pm, n, :q)
    p_ne             = _PM.var(pm, n, :p_ne)
    q_ne             = _PM.var(pm, n, :q_ne)
    pg               = _PM.var(pm, n, :pg)
    qg               = _PM.var(pm, n, :qg)
    ps               = _PM.var(pm, n, :ps)
    qs               = _PM.var(pm, n, :qs)
    ps_ne            = _PM.var(pm, n, :ps_ne)
    qs_ne            = _PM.var(pm, n, :qs_ne)
    pflex            = _PM.var(pm, n, :pflex)
    qflex            = _PM.var(pm, n, :qflex)
    w                = _PM.var(pm, n, :w, i)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*w)
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - sum(qs[s] for s in bus_storage) - sum(qs_ne[s] for s in bus_storage_ne) - sum(qflex[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*w)
end

#Constraint template:  Power Balance constraint with power interrupted by contingency - pinter (including candidate storage & flexible demand)
function constraint_power_balance_reliability(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_arcs_dc = PowerModels.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = PowerModels.ref(pm, nw, :bus_convs_ac, i)
    bus_convs_ac_ne = PowerModels.ref(pm, nw, :bus_convs_ac_ne, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)

    constraint_power_balance_reliability(pm, nw, i, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end

# Power Balance constraint  with power interrupted by contingency - pinter (including candidate storage & flexible demand)
function constraint_power_balance_reliability(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne = _PM.var(pm, n, :pconv_ac_ne)
    p_ne = _PM.var(pm, n, :p_ne)
    ps   = _PM.var(pm, n, :ps)
    ps_ne   = _PM.var(pm, n, :ps_ne)
    pflex = _PM.var(pm, n, :pflex)
    pinter = _PM.var(pm, n, :pinter)
    v = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) + sum(pinter[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end
