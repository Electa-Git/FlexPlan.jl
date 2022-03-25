## Problems

function build_max_import(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    constraint_same_investments(pm)
    objective_max_import(pm)
end

function build_max_export(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_load_pcurt_zero(pm, n)
    end
    constraint_same_investments(pm)
    objective_max_export(pm)
end

function build_min_cost_with_same_investments_in_all_sub_nws(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_load_pcurt_zero(pm, n)
    end
    constraint_same_investments(pm)
    objective_min_investment_cost(pm)
end

function build_max_import_with_current_investments(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
    end
    objective_max_import(pm)
end

function build_max_export_with_current_investments(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_load_pcurt_zero(pm, n)
    end
    objective_max_export(pm)
end

function build_min_cost_with_fixed_investments(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = true, intertemporal_constraints = true)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
    end
end

function build_max_flex_band_with_bounded_cost(pm::_PM.AbstractBFModel)
    _FP.post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_load_pcurt_zero(pm, n)
    end
    constraint_same_investments(pm)
    constraint_investment_cost_max(pm; sub_nw = 1)
    objective_max_flex_band_2sub(pm)
end



## Constraints

"Disable involuntary curtailment of loads"
function constraint_load_pcurt_zero(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :load)
        pcurt = _PM.var(pm, n, :pcurt, i)
        JuMP.@constraint(pm.model, pcurt == 0.0)
    end
end

"Fix investment decisions on candidate branches according to values in data structure"
function constraint_ne_branch_indicator_fix(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_branch)
        indicator = _PM.var(pm, n, :branch_ne, i)
        value = _PM.ref(pm, n, :ne_branch, i, "built")
        JuMP.@constraint(pm.model, indicator == value)
    end
end

"Fix investment decisions on candidate storage according to values in data structure"
function constraint_ne_storage_indicator_fix(pm::_PM.AbstractPowerModel, n::Int)
    for i in _PM.ids(pm, n, :ne_storage)
        indicator = _PM.var(pm, n, :z_strg_ne, i)
        value = _PM.ref(pm, n, :ne_storage, i, "isbuilt")
        JuMP.@constraint(pm.model, indicator == value)
    end
end

"Put an upper bound on investment cost related to a single subnetwork"
function constraint_investment_cost_max(pm::_PM.AbstractPowerModel; sub_nw = 1)
    inv_cost = sum(
            _FP.calc_ne_branch_cost(pm, n)
            + _FP.calc_ne_storage_cost(pm, n)
            + _FP.calc_load_investment_cost(pm, n)
        for n in _FP.nw_ids(pm; hour=1, scenario=1, sub_nw))
    max_cost = pm.ref[:it][_PM.pm_it_sym][:max_cost]

    JuMP.@constraint(pm.model, inv_cost <= max_cost)
end

"Ensure that investment decisions are the same in each subnetwork"
function constraint_same_investments(pm::_PM.AbstractPowerModel)
    for y in 1:_FP.dim_length(pm, :year)
        n_1, rest = Iterators.peel(_FP.nw_ids(pm; hour=1, scenario=1, year=y))
        for n_2 in rest
            for i in _PM.ids(pm, :ne_branch, nw = n_2)
                _FP.constraint_ne_branch_investment_same(pm, n_1, n_2, i)
            end
            for i in _PM.ids(pm, :ne_storage, nw = n_2)
                _FP.constraint_ne_storage_investment_same(pm, n_1, n_2, i)
            end
            n_1 = n_2
        end
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

function objective_max_flex_band_2sub(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Max,
        sum( calc_td_coupling_power_active(pm, n) for n in _FP.nw_ids(pm; hour=1, scenario=1, sub_nw=1) )
        - sum( calc_td_coupling_power_active(pm, n) for n in _FP.nw_ids(pm; hour=1, scenario=1, sub_nw=2) )
    )
end

function objective_min_investment_cost(pm::_PM.AbstractPowerModel)
    investment = sum(
        _FP.calc_ne_branch_cost(pm, n)
        + _FP.calc_ne_storage_cost(pm, n)
        + _FP.calc_load_investment_cost(pm, n)
        for n in _FP.nw_ids(pm; hour=1, scenario=1)
    )
    JuMP.@objective(pm.model, Min, investment)
end
