# Constraint relating to network components or quantities not introduced by FlexPlan


## Power balance

# Power balance including candidate storage
function constraint_power_balance_acne_dcne_strg(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p                = _PM.var(pm, n, :p)
    pg               = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac    = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac         = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne      = _PM.var(pm, n, :pconv_ac_ne)
    p_ne             = _PM.var(pm, n, :p_ne)
    ps               = _PM.var(pm, n, :ps)
    ps_ne            = _PM.var(pm, n, :ps_ne)
    v                = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end

# Power balance (without DC equipment) including candidate storage
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

# Power balance including candidate storage & flexible demand
function constraint_power_balance_acne_dcne_flex(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, gs, bs)
    p                = _PM.var(pm, n, :p)
    pg               = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac    = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac         = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne      = _PM.var(pm, n, :pconv_ac_ne)
    p_ne             = _PM.var(pm, n, :p_ne)
    ps               = _PM.var(pm, n, :ps)
    ps_ne            = _PM.var(pm, n, :ps_ne)
    pflex            = _PM.var(pm, n, :pflex)
    v                = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end

# Power balance (without DC equipment) including candidate storage & flexible demand
function constraint_power_balance_acne_flex(pm::_PM.AbstractWModels, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_gens, bus_loads, bus_shunts, bus_storage, bus_storage_ne, gs, bs)
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
    pflex = _PM.var(pm, n, :pflex)
    qflex = _PM.var(pm, n, :qflex)
    w     = _PM.var(pm, n, :w, i)

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) - sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*w)
    JuMP.@constraint(pm.model, sum(q[a] for a in bus_arcs) + sum(q_ne[a] for a in bus_arcs_ne) == sum(qg[g] for g in bus_gens) - sum(qs[s] for s in bus_storage) - sum(qs_ne[s] for s in bus_storage_ne) - sum(qflex[d] for d in bus_loads) + sum(bs[s] for s in bus_shunts)*w)
end

# Power balance with power interrupted by contingency - pinter (including candidate storage & flexible demand)
function constraint_power_balance_reliability(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, gs, bs)
    p                = _PM.var(pm, n, :p)
    pg               = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac    = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac         = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne      = _PM.var(pm, n, :pconv_ac_ne)
    p_ne             = _PM.var(pm, n, :p_ne)
    ps               = _PM.var(pm, n, :ps)
    ps_ne            = _PM.var(pm, n, :ps_ne)
    pflex            = _PM.var(pm, n, :pflex)
    pinter           = _PM.var(pm, n, :pinter)
    v                = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) + sum(pinter[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end


## Candidate AC branches

# Activate a candidate AC branch depending on the investment decisions in the candidate's horizon.
function constraint_ne_branch_activation(pm::_PM.AbstractPowerModel, n::Int, i::Int, horizon::Vector{Int})
    indicator = _PM.var(pm, n, :branch_ne, i)
    investments = _PM.var.(Ref(pm), horizon, :branch_ne_investment, i)

    JuMP.@constraint(pm.model, indicator == sum(investments))
end


## Candidate DC branches

# Activate a candidate DC branch depending on the investment decisions in the candidate's horizon.
function constraint_ne_branchdc_activation(pm::_PM.AbstractPowerModel, n::Int, i::Int, horizon::Vector{Int})
    indicator = _PM.var(pm, n, :branchdc_ne, i)
    investments = _PM.var.(Ref(pm), horizon, :branchdc_ne_investment, i)

    JuMP.@constraint(pm.model, indicator == sum(investments))
end


## Candidate converters

# Activate a candidate AC/DC converter depending on the investment decisions in the candidate's horizon.
function constraint_ne_converter_activation(pm::_PM.AbstractPowerModel, n::Int, i::Int, horizon::Vector{Int})
    indicator = _PM.var(pm, n, :conv_ne, i)
    investments = _PM.var.(Ref(pm), horizon, :conv_ne_investment, i)

    JuMP.@constraint(pm.model, indicator == sum(investments))
end
