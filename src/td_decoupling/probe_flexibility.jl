function probe_distribution_flexibility!(mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}())
    _FP.require_dim(mn_data, :sub_nw)
    if _FP.dim_length(mn_data, :sub_nw) > 1
        Memento.error(_LOGGER, "A single distribution network is required ($(dim_length(mn_data, :sub_nw)) found)")
    end

    r_base = run_td_decoupling_model(mn_data, _FP.post_simple_stoch_flex_tnep, optimizer; setting)

    add_ne_branch_indicator!(mn_data, r_base)
    add_ne_storage_indicator!(mn_data, r_base)
    add_flex_load_indicator!(mn_data, r_base)

    mn_data_up = deepcopy(mn_data)
    r_up = run_td_decoupling_model(mn_data_up, build_max_import_with_current_investments, optimizer; setting)
    apply_td_coupling_power_active!(mn_data_up, r_up)
    apply_gen_power_active_ub!(mn_data_up, r_base)
    add_storage_power_active_lb!(mn_data_up, r_base)
    add_ne_storage_power_active_lb!(mn_data_up, r_base)
    add_load_power_active_lb!(mn_data_up, r_base)
    r_up = run_td_decoupling_model(mn_data_up, build_min_cost_at_max_import, optimizer; setting)

    mn_data_down = deepcopy(mn_data)
    r_down = run_td_decoupling_model(mn_data_down, build_max_export_with_current_investments, optimizer; setting)
    apply_td_coupling_power_active!(mn_data_down, r_down)
    apply_gen_power_active_lb!(mn_data_down, r_base)
    add_storage_power_active_ub!(mn_data_down, r_base)
    add_ne_storage_power_active_ub!(mn_data_down, r_base)
    add_load_power_active_ub!(mn_data_down, r_base)
    r_down = run_td_decoupling_model(mn_data_down, build_min_cost_at_max_export, optimizer; setting)

    # Store sorted ids of components (nw, branch, etc.).
    ids = Dict{String,Any}("nw" => string.(_FP.nw_ids(mn_data)))
    first_nw = r_base["solution"]["nw"][ids["nw"][1]] # Cannot use mn_data here because it may contain inactive components
    for comp in ("branch", "ne_branch", "storage", "ne_storage", "load")
        if haskey(first_nw, comp)
            ids[comp] = string.(sort(parse.(Int, keys(first_nw[comp]))))
        end
    end

    # Check that investment decisions are the same in each result (only first period is used);
    # create a component key only if component is present in results.
    investment = Dict{String,Any}()
    function _isbuilt(result, component, built_keyword)
        result_comp = result["solution"]["nw"][ids["nw"][1]][component]
        Bool.(round.(result_comp[k][built_keyword] for k in ids[component]))
    end
    for (comp, built_keyword) in ("ne_branch"=>"built", "ne_storage"=>"isbuilt", "load"=>"flex")
        if !isempty(ids[comp])
            built = _isbuilt(r_base, comp, built_keyword)
            for res in (r_up, r_down)
                if built ≠ _isbuilt(res, comp, built_keyword)
                    Memento.error(_LOGGER, "Results of flex candidate \"$name\" have different $comp investment decisions.")
                end
            end
            investment[comp] = Dict{String,Any}(ids[comp] .=> built)
        end
    end

    return Dict{String,Any}(
        "result"     => Dict{String,Any}("up"=>r_up, "base"=>r_base, "down"=>r_down),
        "ids"        => ids,
        "investment" => investment,
    )
end

"Run a model with usual parameters and model type; error if not solved to optimality."
function run_td_decoupling_model(data::Dict{String,Any}, build_function::Function, optimizer; kwargs...)
    Memento.info(_LOGGER, "running $(String(nameof(build_function)))...")
    result = _PM.run_model(
        data, _FP.BFARadPowerModel, optimizer, build_function;
        ref_extensions = [_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!],
        solution_processors = [_PM.sol_data_model!, _FP.sol_td_coupling!],
        multinetwork = true,
        kwargs...
    )
    Memento.info(_LOGGER, "solved $(String(nameof(build_function))) in $(round(Int,result["solve_time"])) seconds")
    if result["termination_status"] ∉ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Unable to solve $(String(nameof(build_function))) ($(result["optimizer"]) termination status: $(result["termination_status"]))")
    end
    return result
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

function add_ne_branch_indicator!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `ne_branch`es have a `br_status` parameter:
    # those whose `br_status` is 0 are not reported in solution dict.
    for (n, data_nw) in mn_data["nw"]
        sol_nw = result["solution"]["nw"][n]
        for (b, data_branch) in data_nw["ne_branch"]
            if data_branch["br_status"] == 1
                data_branch["sol_built"] = sol_nw["ne_branch"][b]["built"]
            end
        end
    end
end

function add_ne_storage_indicator!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "sol_built", result["solution"], "isbuilt")
end

function add_flex_load_indicator!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "sol_built", result["solution"], "flex")
end

function add_load_power_active_ub!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "pflex_ub", result["solution"], "pflex")
end

function add_load_power_active_lb!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "load", "pflex_lb", result["solution"], "pflex")
end

function apply_td_coupling_power_active!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        p = result["solution"]["nw"][n]["td_coupling"]["p"]
        d_gen_id = _FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen")
        d_gen = data_nw["gen"]["$d_gen_id"] = deepcopy(data_nw["gen"]["$d_gen_id"]) # Gen data is shared among nws originally.
        d_gen["pmax"] = p
        d_gen["pmin"] = p
    end
end

function apply_gen_power_active_ub!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `d_gen` must not be changed.
    for (n, data_nw) in mn_data["nw"]
        d_gen_id = string(_FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen"))
        sol_nw = result["solution"]["nw"][n]
        for (g, data_gen) in data_nw["gen"]
            if g ≠ d_gen_id
                data_gen["pmax"] = sol_nw["gen"][g]["pg"]
            end
        end
    end
end

function apply_gen_power_active_lb!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    # Cannot use `_copy_comp_key!` because `d_gen` must not be changed.
    for (n, data_nw) in mn_data["nw"]
        d_gen_id = string(_FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen"))
        sol_nw = result["solution"]["nw"][n]
        for (g, data_gen) in data_nw["gen"]
            if g ≠ d_gen_id
                data_gen["pmin"] = sol_nw["gen"][g]["pg"]
            end
        end
    end
end

function add_storage_power_active_ub!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "storage", "ps_ub", result["solution"], "ps")
end

function add_storage_power_active_lb!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "storage", "ps_lb", result["solution"], "ps")
end

function add_ne_storage_power_active_ub!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "ps_ne_ub", result["solution"], "ps_ne")
end

function add_ne_storage_power_active_lb!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    _copy_comp_key!(mn_data, "ne_storage", "ps_ne_lb", result["solution"], "ps_ne")
end



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
