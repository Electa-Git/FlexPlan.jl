## Problems

function build_max_import_with_current_investments(pm::_PM.AbstractBFModel)
    _FP.post_simple_stoch_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_flex_load_indicator_fix(pm, n)
    end
    objective_max_import(pm)
end

function build_max_export_with_current_investments(pm::_PM.AbstractBFModel)
    _FP.post_simple_stoch_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_flex_load_indicator_fix(pm, n)
    end
    objective_max_export(pm)
end

function build_min_cost_at_max_import(pm::_PM.AbstractBFModel)
    _FP.post_simple_stoch_flex_tnep(pm; objective = true, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_flex_load_indicator_fix(pm, n)
        # td_coupling_power_active already fixed in data
        # gen_power_active_ub already applied in data
        constraint_storage_power_active_lb(pm, n)
        constraint_ne_storage_power_active_lb(pm, n)
        constraint_load_power_active_lb(pm, n)
    end
end

function build_min_cost_at_max_export(pm::_PM.AbstractBFModel)
    _FP.post_simple_stoch_flex_tnep(pm; objective = true, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_flex_load_indicator_fix(pm, n)
        # td_coupling_power_active already fixed in data
        # gen_power_active_lb already applied in data
        constraint_storage_power_active_ub(pm, n)
        constraint_ne_storage_power_active_ub(pm, n)
        constraint_load_power_active_ub(pm, n)
    end
end



## Constraints

"Fix investment decisions on candidate branches according to values in data structure"
function constraint_ne_branch_indicator_fix(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_branch)
        indicator = _PM.var(pm, n, :branch_ne, i)
        value = _PM.ref(pm, n, :ne_branch, i, "sol_built")
        JuMP.@constraint(pm.model, indicator == value)
    end
end

"Fix investment decisions on candidate storage according to values in data structure"
function constraint_ne_storage_indicator_fix(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_storage)
        indicator = _PM.var(pm, n, :z_strg_ne, i)
        value = _PM.ref(pm, n, :ne_storage, i, "sol_built")
        JuMP.@constraint(pm.model, indicator == value)
    end
end

"Fix investment decisions on flexibility of loads according to values in data structure"
function constraint_flex_load_indicator_fix(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :flex_load)
        indicator = _PM.var(pm, n, :z_flex, i)
        value = _PM.ref(pm, n, :flex_load, i, "sol_built")
        JuMP.@constraint(pm.model, indicator == value)
    end
end

"Put an upper bound on the active power absorbed by loads"
function constraint_load_power_active_ub(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :load)
        pflex = _PM.var(pm, n, :pflex, i)
        ub = _PM.ref(pm, n, :load, i, "pflex_ub")
        JuMP.set_upper_bound(pflex, ub)
    end
end

"Put a lower bound on the active power absorbed by loads"
function constraint_load_power_active_lb(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :load)
        pflex = _PM.var(pm, n, :pflex, i)
        lb = _PM.ref(pm, n, :load, i, "pflex_lb")
        JuMP.set_lower_bound(pflex, lb)
    end
end

"Put an upper bound on the active power exchanged by storage (load convention)"
function constraint_storage_power_active_ub(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :storage)
        ps = _PM.var(pm, n, :ps, i)
        ub = _PM.ref(pm, n, :storage, i, "ps_ub")
        JuMP.set_upper_bound(ps, ub)
    end
end

"Put a lower bound on the active power exchanged by storage (load convention)"
function constraint_storage_power_active_lb(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :storage)
        ps = _PM.var(pm, n, :ps, i)
        lb = _PM.ref(pm, n, :storage, i, "ps_lb")
        JuMP.set_lower_bound(ps, lb)
    end
end

"Put an upper bound on the active power exchanged by candidate storage (load convention)"
function constraint_ne_storage_power_active_ub(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_storage)
        ps = _PM.var(pm, n, :ps_ne, i)
        ub = _PM.ref(pm, n, :ne_storage, i, "ps_ne_ub")
        JuMP.set_upper_bound(ps, ub)
    end
end

"Put a lower bound on the active power exchanged by candidate storage (load convention)"
function constraint_ne_storage_power_active_lb(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_storage)
        ps = _PM.var(pm, n, :ps_ne, i)
        lb = _PM.ref(pm, n, :ne_storage, i, "ps_ne_lb")
        JuMP.set_lower_bound(ps, lb)
    end
end



## Objectives

function objective_max_import(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Max,
        sum( calc_td_coupling_power_active(pm, n) for (n, nw_ref) in _PM.nws(pm) )
    )
end

function objective_max_export(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
        sum( calc_td_coupling_power_active(pm, n) for (n, nw_ref) in _PM.nws(pm) )
    )
end

function calc_td_coupling_power_active(pm::_PM.AbstractPowerModel, n::Int)
    pcc_gen = _FP.dim_prop(pm, n, :sub_nw, "d_gen")
    p = _PM.var(pm, n, :pg, pcc_gen)
    return p
end
