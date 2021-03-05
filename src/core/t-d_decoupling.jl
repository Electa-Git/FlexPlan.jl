"Return some planning options for a dist network that also provide flexibility to transmission."
function solve_td_coupling_distribution(sn_data::Dict{String,Any}, mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}(), number_of_candidates)
    if !haskey(mn_data, "sub_nw")
        Memento.error(_LOGGER, "A distribution network is required")
    end
    if length(mn_data["sub_nw"]) > 1
        Memento.error(_LOGGER, "A single distribution network is required ($(length(mn_data["sub_nw"])) found)")
    end
    if number_of_candidates < 1
        Memento.warn(_LOGGER, "The number of requested distribution network planning candidates must be positive: substituting $number_of_candidates with 1.")
        number_of_candidates = 1
    end

    candidates = Dict{String,Any}()
    add_dist_candidate!(candidates, min_investments(mn_data, optimizer, setting)...)
    if number_of_candidates >= 2
        add_dist_candidate!(candidates, max_power(mn_data, optimizer, setting)...)
        add_dist_candidates_cost!(candidates, sn_data)
        if number_of_candidates > 2
            intermediate_costs = collect(range(candidates["min"]["cost"], candidates["max"]["cost"], length = number_of_candidates)[2:end-1])
            for i in 1:number_of_candidates-2
                add_dist_candidate!(candidates, intermediate_investment(mn_data, i, intermediate_costs[i], optimizer, setting)...)
            end
        end
    end
    add_dist_candidates_cost!(candidates, sn_data)
    return candidates
end

"Run a model with usual parameters and model type; error if not solved to optimality."
function run_td_coupling_model(data::Dict{String,Any}, build_function::Function, optimizer; kwargs...)
    Memento.info(_LOGGER, "running $(String(nameof(build_function)))...")
    result = _PM.run_model(
        data, BFARadPowerModel, optimizer, build_function;
        ref_extensions = [add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, ref_add_ne_branch_allbranches!, ref_add_frb_branch!, ref_add_oltc_branch!],
        solution_processors = [_PM.sol_data_model!, sol_td_coupling!],
        multinetwork = true,
        kwargs...
    )
    Memento.info(_LOGGER, "solved $(String(nameof(build_function))) in $(round(Int,result["solve_time"])) seconds")
    if result["termination_status"] ∉ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED)
        Memento.error(_LOGGER, "Unable to solve $(String(nameof(build_function))) ($(result["optimizer"]) termination status: $(result["termination_status"]))")
    end
    return result
end



## Distribution candidates


function min_investments(mn_data, optimizer, setting)
    min_base = run_td_coupling_model(mn_data, post_flex_tnep, optimizer; setting)

    mn_data_current_investments = deepcopy(mn_data)
    add_ne_branch_indicator!(mn_data_current_investments, min_base)
    add_ne_storage_indicator!(mn_data_current_investments, min_base)
    
    min_import = run_td_coupling_model(mn_data_current_investments, build_max_import_with_current_investments, optimizer; setting)
    min_export = run_td_coupling_model(mn_data_current_investments, build_max_export_with_current_investments, optimizer; setting)

    return ("min", min_import, min_export, min_base)
end

function max_power(mn_data, optimizer, setting)
    max_import_1 = run_td_coupling_model(mn_data, build_max_import, optimizer; setting)
    mn_data_max_import_2 = deepcopy(mn_data)
    add_td_coupling_power_active!(mn_data_max_import_2, max_import_1)

    max_export_1 = run_td_coupling_model(mn_data, build_max_export, optimizer; setting)
    mn_data_max_export_2 = deepcopy(mn_data)
    add_td_coupling_power_active!(mn_data_max_export_2, max_export_1)
    shift_sub_nw!(mn_data_max_export_2)

    mn_data_max_pair = merge_multinetworks(mn_data_max_import_2, mn_data_max_export_2)
    max_pair = run_td_coupling_model(mn_data_max_pair, build_min_cost_with_same_investments_in_all_sub_nws, optimizer; setting)
    max_import, max_export = split_result(max_pair)

    mn_data_max_base = deepcopy(mn_data) 
    add_ne_branch_indicator!(mn_data_max_base, max_import) # Same investments as max_export
    add_ne_storage_indicator!(mn_data_max_base, max_import) # Same investments as max_export
    max_base = run_td_coupling_model(mn_data_max_base, build_min_cost_with_fixed_investments, optimizer; setting)

    return ("max", max_import, max_export, max_base)
end

function intermediate_investment(mn_data, i, intermediate_cost, optimizer, setting; kwargs...)
    mn_data_1 = deepcopy(mn_data)
    mn_data_2 = deepcopy(mn_data)
    shift_sub_nw!(mn_data_2)
    mn_data_pair = merge_multinetworks(mn_data_1, mn_data_2)
    add_max_cost!(mn_data_pair, intermediate_cost)
    pair_1 = run_td_coupling_model(mn_data_pair, build_max_flex_band_with_bounded_cost, optimizer; setting, kwargs...)

    add_td_coupling_power_active!(mn_data_pair, pair_1)
    pair_2 = run_td_coupling_model(mn_data_pair, build_min_cost_with_same_investments_in_all_sub_nws, optimizer; setting, kwargs...)
    i_import, i_export = split_result(pair_2)

    mn_data_base = deepcopy(mn_data) 
    add_ne_branch_indicator!(mn_data_base, i_import) # Same investments as i_export
    add_ne_storage_indicator!(mn_data_base, i_import) # Same investments as i_export
    i_base = run_td_coupling_model(mn_data_base, build_min_cost_with_fixed_investments, optimizer; setting, kwargs...)

    return ("intermediate_$i", i_import, i_export, i_base)
end



## Result - data structure interaction

# These functions allow to pass investment decisions between two problems: the investment decision
# results of the first problem are copied into the data structure of the second problem; an
# appropriate constraint could be necessary in the model of the second problem to read the data
# prepared by these functions.

function add_ne_branch_indicator!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        sol_nw = result["solution"]["nw"][n]
        for (b, data_branch) in data_nw["ne_branch"]
            if data_branch["br_status"] == 1
                data_branch["built"] = sol_nw["ne_branch"][b]["built"]
            end
        end
    end
end

function add_ne_storage_indicator!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        sol_nw = result["solution"]["nw"][n]
        for (s, data_storage) in data_nw["ne_storage"]
            data_storage["isbuilt"] = sol_nw["ne_storage"][s]["isbuilt"]
        end
    end
end

# Works even if both mn_data and result have multiple subnetworks
function add_td_coupling_power_active!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        p = result["solution"]["nw"][n]["td_coupling"]["p"]
        d_gen_id = data_nw["td_coupling"]["d_gen"]
        d_gen = data_nw["gen"]["$d_gen_id"] = deepcopy(data_nw["gen"]["$d_gen_id"]) # Gen data is shared among nws originally.
        d_gen["pmax"] = p
        d_gen["pmin"] = p
    end
end

function add_max_cost!(mn_data::Dict{String,Any}, max_cost::Float64)
    mn_data["max_cost"] = max_cost
end



## Problems

function build_max_import(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    constraint_same_investments(pm)
    objective_max_import(pm)
end

function build_max_export(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_load_pcurt_zero(pm, n)
    end
    constraint_same_investments(pm)
    objective_max_export(pm)
end

function build_min_cost_with_same_investments_in_all_sub_nws(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_load_pcurt_zero(pm, n)
    end
    constraint_same_investments(pm)
    objective_min_investment_cost(pm)
end

function build_max_import_with_current_investments(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
    end
    objective_max_import(pm)
end

function build_max_export_with_current_investments(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
        constraint_load_pcurt_zero(pm, n)
    end
    objective_max_export(pm)
end

function build_min_cost_with_fixed_investments(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = true, intertemporal_constraints = true)
    for n in _PM.nw_ids(pm)
        constraint_ne_branch_indicator_fix(pm, n)
        constraint_ne_storage_indicator_fix(pm, n)
    end
end

function build_max_flex_band_with_bounded_cost(pm::_PM.AbstractBFModel)
    post_flex_tnep(pm; objective = false, intertemporal_constraints = false)
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
            calc_ne_branch_cost(pm, n, false)
            + calc_ne_storage_cost(pm, n, false)
            + calc_load_cost_inv(pm, n, false)
        for n in pm.ref[:sub_nw]["$sub_nw"])
    max_cost = pm.ref[:max_cost]
            
    JuMP.@constraint(pm.model, inv_cost <= max_cost)
end

"Ensure that investment decisions are the same, spanning over periods and possibly multiple subnetworks"
function constraint_same_investments(pm::_PM.AbstractPowerModel)
    sorted_nw_ids = sort(collect(_PM.nw_ids(pm)))
    n_1 = first(sorted_nw_ids)
    for n_2 in sorted_nw_ids[2:end]
        for i in _PM.ids(pm, :ne_branch, nw = n_2)
            # Constrains binary activation variable of ne_branch i to the same value in n_2-1 and n_2 nws
            _PMACDC.constraint_candidate_acbranches_mp(pm, n_2, i)
        end
        for i in _PM.ids(pm, :ne_storage, nw = n_2)
            constraint_storage_investment(pm, n_1, n_2, i)
        end
        n_1 = n_2
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
    pcc_gen = _PM.ref(pm, n, :td_coupling, "d_gen")
    p = _PM.var(pm, n, :pg, pcc_gen)
    return p
end

function objective_max_flex_band_2sub(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Max,
        sum( calc_td_coupling_power_active(pm, n) for n in pm.ref[:sub_nw]["1"] )
        - sum( calc_td_coupling_power_active(pm, n) for n in pm.ref[:sub_nw]["2"] )
    )
end

function objective_min_investment_cost(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
        sum(
            calc_ne_branch_cost(pm, n, false)
            + calc_ne_storage_cost(pm, n, false)
            + calc_load_cost_inv(pm, n, false)
        for (n, nw_ref) in _PM.nws(pm))
    )
end
    
function calc_load_cost_inv(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    load = _PM.ref(pm, n, :load)
    cost = sum(l["cost_investment"]*_PM.var(pm, n, :z_flex, i) for (i,l) in load)
    if add_co2_cost
        cost += sum(l["co2_cost"]*_PM.var(pm, n, :z_flex, i) for (i,l) in load)
    end
    return cost
end



## Results

"""
Generate two results from one result of a run command, by assigning half of nws to each result

Nw ids of the original result are ordered and splitted; the first half is used in both the generated
results. Other fields are copied.
"""
function split_result(res::Dict{String,Any})
    res_1 = Dict{String,Any}()
    res_2 = Dict{String,Any}()
    for (k_res,v_res) in res
        if k_res == "solution"
            res_1["solution"] = Dict{String,Any}()
            res_2["solution"] = Dict{String,Any}()
            for (k_sol, v_sol) in v_res
                if k_sol == "nw"
                    nw_ids = string.(sort(parse.(Int,keys(v_sol))))
                    if isodd(length(nw_ids))
                        Memento.error(_LOGGER, "Attempting to split a result having an odd number of nws.")
                    else
                        nn = length(nw_ids)
                        nw_ids_1 = nw_ids[1:nn÷2]
                        nw_ids_2 = nw_ids[nn÷2+1:nn]
                        res_1["solution"]["nw"] = Dict{String,Any}()
                        res_2["solution"]["nw"] = Dict{String,Any}()
                        for pos in 1:nn÷2
                            res_1["solution"]["nw"][nw_ids_1[pos]] = v_sol[nw_ids_1[pos]]
                            res_2["solution"]["nw"][nw_ids_1[pos]] = v_sol[nw_ids_2[pos]] # In res_2 the same nw_ids of res_1 are used
                        end
                    end
                else
                    res_1["solution"][k_sol] = v_sol
                    res_2["solution"][k_sol] = deepcopy(v_sol)
                end
            end
        else
            res_1[k_res] = v_res
            res_2[k_res] = deepcopy(v_res)
        end
    end
    return res_1, res_2
end



## Distribution candidates handling

function add_dist_candidate!(dist_candidates::Dict{String,Any}, name::String, r_import::Dict{String,Any}, r_export::Dict{String,Any}, r_base::Dict{String,Any} = Dict{String,Any}())
    
    c = dist_candidates[name] = Dict{String,Any}()

    result = c["result"] = Dict{String,Any}()
    result["export"] = r_export
    result["import"] = r_import
    if !isempty(r_base)
        result["base"] = r_base
    end

    # Results to compare with: r_export is used at first, then r_import and possibly r_base are compared with r_export.
    ctrl_res = isempty(r_base) ? (r_import,) : (r_import, r_base)

    # Store ordered ids of components (nw, branch, etc.) and check that they are the same in each result.
    ids = c["ids"] = Dict{String,Any}()
    ids["nw"] = keys(r_export["solution"]["nw"])
    for res in ctrl_res
        if ids["nw"] ≠ keys(res["solution"]["nw"])
            Memento.error(_LOGGER, "Results of flex candidate \"$name\" have different nw ids.")
        end
    end
    ids["nw"] = string.(sort(parse.(Int, ids["nw"])))
    first_period = ids["nw"][1]
    for comp in ("branch", "ne_branch", "storage", "ne_storage")
        if haskey(r_export["solution"]["nw"][first_period], comp)
            comp_keys = keys(r_export["solution"]["nw"][first_period][comp])
            for res in ctrl_res
                if comp_keys ≠ keys(res["solution"]["nw"][first_period][comp])
                    Memento.error(_LOGGER, "Results of flex candidate \"$name\" have different $comp ids.")
                end
            end
            ids[comp] = string.(sort(parse.(Int, comp_keys)))
        else
            ids[comp] = Vector{String}()
        end
    end

    # Check that investment decisions are the same in each result (only first period is used);
    # create a component key only if component is present in results.
    investment = c["investment"] = Dict{String,Any}()
    function _isbuilt(result, component, built_keyword)
        Bool.(round.(result["solution"]["nw"][first_period][component][k][built_keyword] for k in ids[component]))
    end
    for (comp, built_keyword) in ("ne_branch"=>"built", "ne_storage"=>"isbuilt")
        if !isempty(ids[comp])
            built = _isbuilt(r_export, comp, built_keyword)
            for res in ctrl_res
                if built ≠ _isbuilt(res, comp, built_keyword)
                    Memento.error(_LOGGER, "Results of flex candidate \"$name\" have different $comp investment descisions.")
                end
            end
            investment[comp] = Dict{String,Any}(ids[comp] .=> built)
        end
    end
end

function add_dist_candidates_cost!(dist_candidates::Dict{String,Any}, sn_data::Dict{String,Any})
    cost_lookup = Dict{String,Any}()
    cl_ne_branch = cost_lookup["ne_branch"] = Dict{String,Any}()
    for (b, branch) in sn_data["ne_branch"]
        cl_ne_branch[b] = branch["construction_cost"]
    end
    cl_ne_storage = cost_lookup["ne_storage"] = Dict{String,Any}()
    for (s, storage) in sn_data["ne_storage"]
        cl_ne_storage[s] = storage["eq_cost"] + storage["inst_cost"]
    end

    for candidate in values(dist_candidates) 
        candidate["cost"] = sum( sum( cost_lookup[comp_name][id] * length(candidate["ids"]["nw"]) * built for (id, built) in comp_inv ) for (comp_name, comp_inv) in candidate["investment"])
    end
end
