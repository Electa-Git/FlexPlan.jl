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
