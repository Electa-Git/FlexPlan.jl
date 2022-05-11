function probe_distribution_flexibility!(mn_data::Dict{String,Any}; model_type, optimizer, build_method, ref_extensions, solution_processors, setting=Dict{String,Any}(), direct_model=false)
    _FP.require_dim(mn_data, :sub_nw)
    if _FP.dim_length(mn_data, :sub_nw) > 1
        Memento.error(_LOGGER, "A single distribution network is required ($(_FP.dim_length(mn_data, :sub_nw)) found)")
    end

    sol_base = run_td_decoupling_model(mn_data; model_type, optimizer, build_method, ref_extensions, solution_processors, setting, direct_model)

    add_ne_branch_indicator!(mn_data, sol_base)
    add_ne_storage_indicator!(mn_data, sol_base)
    add_flex_load_indicator!(mn_data, sol_base)

    mn_data_up = deepcopy(mn_data)
    apply_gen_power_active_ub!(mn_data_up, sol_base)
    add_storage_power_active_lb!(mn_data_up, sol_base)
    add_ne_storage_power_active_lb!(mn_data_up, sol_base)
    add_load_power_active_lb!(mn_data_up, sol_base)
    sol_up = run_td_decoupling_model(mn_data_up; model_type, optimizer, build_method=build_max_import_with_current_investments_monotonic(build_method), ref_extensions, solution_processors, setting, direct_model, relax_integrality=true)
    apply_td_coupling_power_active!(mn_data_up, sol_up)
    sol_up = run_td_decoupling_model(mn_data_up; model_type, optimizer, build_method=build_min_cost_at_max_import_monotonic(build_method), ref_extensions, solution_processors, setting, direct_model, relax_integrality=true)

    mn_data_down = deepcopy(mn_data)
    apply_gen_power_active_lb!(mn_data_down, sol_base)
    add_storage_power_active_ub!(mn_data_down, sol_base)
    add_ne_storage_power_active_ub!(mn_data_down, sol_base)
    add_load_power_active_ub!(mn_data_down, sol_base)
    sol_down = run_td_decoupling_model(mn_data_down; model_type, optimizer, build_method=build_max_export_with_current_investments_monotonic(build_method), ref_extensions, solution_processors, setting, direct_model, relax_integrality=true)
    apply_td_coupling_power_active!(mn_data_down, sol_down)
    sol_down = run_td_decoupling_model(mn_data_down; model_type, optimizer, build_method=build_min_cost_at_max_export_monotonic(build_method), ref_extensions, solution_processors, setting, direct_model, relax_integrality=true)

    return sol_up, sol_base, sol_down
end

"Run a model, ensure it is solved to optimality (error otherwise), return solution."
function run_td_decoupling_model(data::Dict{String,Any}; model_type::Type, optimizer, build_method::Function, ref_extensions, solution_processors, setting, relax_integrality=false, return_solution::Bool=true, direct_model=false, kwargs...)
    start_time = time()
    Memento.debug(_LOGGER, "┌ running $(String(nameof(build_method)))...")
    if direct_model
        result = _PM.run_model(
            data, model_type, nothing, build_method;
            ref_extensions,
            solution_processors,
            multinetwork = true,
            relax_integrality,
            setting,
            jump_model = JuMP.direct_model(optimizer),
            kwargs...
        )
    else
        result = _PM.run_model(
            data, model_type, optimizer, build_method;
            ref_extensions,
            solution_processors,
            multinetwork = true,
            relax_integrality,
            setting,
            kwargs...
        )
    end
    Memento.debug(_LOGGER, "└ solved in $(round(time()-start_time;sigdigits=3)) seconds (of which $(round(result["solve_time"];sigdigits=3)) seconds for solver)")
    if result["termination_status"] ∉ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Unable to solve $(String(nameof(build_method))) ($(result["optimizer"]) termination status: $(result["termination_status"]))")
    end
    return return_solution ? result["solution"] : result
end



## Result - data structure interaction

# These functions allow to pass investment decisions between two problems: the investment
# decision results of the first problem are copied into the data structure of the second
# problem; an appropriate constraint may be necessary in the model of the second problem to
# read the data prepared by these functions.

function _copy_comp_key!(target_data::Dict{String,Any}, comp::String, target_key::String, source_data::Dict{String,Any}, source_key::String=target_key)
    for (n, target_nw) in target_data["nw"]
        source_nw = source_data["nw"][n]
        for (i, target_comp) in target_nw[comp]
            target_comp[target_key] = source_nw[comp][i][source_key]
        end
    end
end

function add_ne_branch_indicator!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `ne_branch`es have a `br_status` parameter:
    # those whose `br_status` is 0 are not reported in solution dict.
    for (n, data_nw) in mn_data["nw"]
        sol_nw = solution["nw"][n]
        for (b, data_branch) in data_nw["ne_branch"]
            if data_branch["br_status"] == 1
                data_branch["sol_built"] = sol_nw["ne_branch"][b]["built"]
            end
        end
    end
end

function add_ne_storage_indicator!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "sol_built", solution, "isbuilt")
end

function add_flex_load_indicator!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "sol_built", solution, "flex")
end

function add_load_power_active_ub!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "pflex_ub", solution, "pflex")
end

function add_load_power_active_lb!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "pflex_lb", solution, "pflex")
end

function apply_td_coupling_power_active!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        p = solution["nw"][n]["td_coupling"]["p"]
        d_gen_id = _FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen")
        d_gen = data_nw["gen"]["$d_gen_id"] = deepcopy(data_nw["gen"]["$d_gen_id"]) # Gen data is shared among nws originally.
        d_gen["pmax"] = p
        d_gen["pmin"] = p
    end
end

function apply_gen_power_active_ub!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `d_gen` must not be changed.
    for (n, data_nw) in mn_data["nw"]
        d_gen_id = string(_FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen"))
        sol_nw = solution["nw"][n]
        for (g, data_gen) in data_nw["gen"]
            if g ≠ d_gen_id
                data_gen["pmax"] = sol_nw["gen"][g]["pg"]
            end
        end
    end
end

function apply_gen_power_active_lb!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `d_gen` must not be changed.
    for (n, data_nw) in mn_data["nw"]
        d_gen_id = string(_FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen"))
        sol_nw = solution["nw"][n]
        for (g, data_gen) in data_nw["gen"]
            if g ≠ d_gen_id
                data_gen["pmin"] = sol_nw["gen"][g]["pg"]
            end
        end
    end
end

function add_storage_power_active_ub!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "storage", "ps_ub", solution, "ps")
end

function add_storage_power_active_lb!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "storage", "ps_lb", solution, "ps")
end

function add_ne_storage_power_active_ub!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "ps_ne_ub", solution, "ps_ne")
end

function add_ne_storage_power_active_lb!(mn_data::Dict{String,Any}, solution::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "ps_ne_lb", solution, "ps_ne")
end



## Problems

function build_max_import(build_method::Function)
    function build_max_import(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        objective_max_import(pm)
    end
end

function build_max_export(build_method::Function)
    function build_max_export(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        objective_max_export(pm)
    end
end

function build_max_import_with_current_investments(build_method::Function)
    function build_max_import_with_current_investments(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        for n in _PM.nw_ids(pm)
            constraint_ne_branch_indicator_fix(pm, n)
            constraint_ne_storage_indicator_fix(pm, n)
            constraint_flex_load_indicator_fix(pm, n)
        end
        objective_max_import(pm)
    end
end

function build_max_export_with_current_investments(build_method::Function)
    function build_max_export_with_current_investments(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        for n in _PM.nw_ids(pm)
            constraint_ne_branch_indicator_fix(pm, n)
            constraint_ne_storage_indicator_fix(pm, n)
            constraint_flex_load_indicator_fix(pm, n)
        end
        objective_max_export(pm)
    end
end

function build_max_import_with_current_investments_monotonic(build_method::Function)
    function build_max_import_with_current_investments_monotonic(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        for n in _PM.nw_ids(pm)
            constraint_ne_branch_indicator_fix(pm, n)
            constraint_ne_storage_indicator_fix(pm, n)
            constraint_flex_load_indicator_fix(pm, n)
            # gen_power_active_ub already applied in data
            constraint_storage_power_active_lb(pm, n)
            constraint_ne_storage_power_active_lb(pm, n)
            constraint_load_power_active_lb(pm, n)
        end
        objective_max_import(pm)
    end
end

function build_max_export_with_current_investments_monotonic(build_method::Function)
    function build_max_export_with_current_investments_monotonic(pm::_PM.AbstractBFModel)
        build_method(pm; objective = false, intertemporal_constraints = false)
        for n in _PM.nw_ids(pm)
            constraint_ne_branch_indicator_fix(pm, n)
            constraint_ne_storage_indicator_fix(pm, n)
            constraint_flex_load_indicator_fix(pm, n)
            # gen_power_active_lb already applied in data
            constraint_storage_power_active_ub(pm, n)
            constraint_ne_storage_power_active_ub(pm, n)
            constraint_load_power_active_ub(pm, n)
        end
        objective_max_export(pm)
    end
end

function build_min_cost_at_max_import_monotonic(build_method::Function)
    function build_min_cost_at_max_import_monotonic(pm::_PM.AbstractBFModel)
        build_method(pm; objective = true, intertemporal_constraints = false)
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
end

function build_min_cost_at_max_export_monotonic(build_method::Function)
    function build_min_cost_at_max_export_monotonic(pm::_PM.AbstractBFModel)
        build_method(pm; objective = true, intertemporal_constraints = false)
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
    # There is no need to distinguish between scenarios because they are independent.
    return JuMP.@objective(pm.model, Max,
        sum( calc_td_coupling_power_active(pm, n) for (n, nw_ref) in _PM.nws(pm) )
    )
end

function objective_max_export(pm::_PM.AbstractPowerModel)
    # There is no need to distinguish between scenarios because they are independent.
    return JuMP.@objective(pm.model, Min,
        sum( calc_td_coupling_power_active(pm, n) for (n, nw_ref) in _PM.nws(pm) )
    )
end

function calc_td_coupling_power_active(pm::_PM.AbstractPowerModel, n::Int)
    pcc_gen = _FP.dim_prop(pm, n, :sub_nw, "d_gen")
    p = _PM.var(pm, n, :pg, pcc_gen)
    return p
end
