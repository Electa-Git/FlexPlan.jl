"Return some planning options for a dist network that also provide flexibility to transmission."
function solve_td_decoupling_distribution(mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}(), number_of_candidates)
    _FP.require_dim(mn_data, :sub_nw)
    if _FP.dim_length(mn_data, :sub_nw) > 1
        Memento.error(_LOGGER, "A single distribution network is required ($(dim_length(mn_data, :sub_nw)) found)")
    end
    if number_of_candidates < 1
        Memento.warn(_LOGGER, "The number of requested distribution network planning candidates must be positive: substituting $number_of_candidates with 1.")
        number_of_candidates = 1
    end

    candidates = Dict{String,Any}()
    add_dist_candidate!(candidates, min_investments(mn_data, optimizer, setting)...)
    if number_of_candidates >= 2
        add_dist_candidate!(candidates, max_power(mn_data, optimizer, setting)...)
        add_dist_candidates_cost!(candidates, mn_data)
        if number_of_candidates > 2
            intermediate_costs = collect(range(candidates["min"]["cost"], candidates["max"]["cost"], length = number_of_candidates)[2:end-1])
            for i in 1:number_of_candidates-2
                add_dist_candidate!(candidates, intermediate_investment(mn_data, i, intermediate_costs[i], optimizer, setting)...)
            end
        end
    end
    add_dist_candidates_cost!(candidates, mn_data)
    return candidates
end

"Run a model with usual parameters and model type; error if not solved to optimality."
function run_td_decoupling_model(data::Dict{String,Any}, build_function::Function, optimizer; kwargs...)
    Memento.info(_LOGGER, "running $(String(nameof(build_function)))...")
    result = _PM.run_model(
        data, _FP.BFARadPowerModel, optimizer, build_function;
        ref_extensions = [_FP.add_candidate_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!],
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



## Distribution candidates


function min_investments(mn_data, optimizer, setting)
    min_base = run_td_decoupling_model(mn_data, _FP.post_flex_tnep, optimizer; setting)

    mn_data_current_investments = deepcopy(mn_data)
    add_ne_branch_indicator!(mn_data_current_investments, min_base)
    add_ne_storage_indicator!(mn_data_current_investments, min_base)

    min_import = run_td_decoupling_model(mn_data_current_investments, build_max_import_with_current_investments, optimizer; setting)
    min_export = run_td_decoupling_model(mn_data_current_investments, build_max_export_with_current_investments, optimizer; setting)

    return ("min", min_import, min_export, min_base)
end

function max_power(mn_data, optimizer, setting)
    max_import_1 = run_td_decoupling_model(mn_data, build_max_import, optimizer; setting)
    mn_data_max_import_2 = deepcopy(mn_data)
    add_td_coupling_power_active!(mn_data_max_import_2, max_import_1)

    max_export_1 = run_td_decoupling_model(mn_data, build_max_export, optimizer; setting)
    mn_data_max_export_2 = deepcopy(mn_data)
    add_td_coupling_power_active!(mn_data_max_export_2, max_export_1)
    _FP.shift_nws!(mn_data_max_export_2)

    mn_data_max_pair = _FP.merge_multinetworks!(mn_data_max_import_2, mn_data_max_export_2, :sub_nw)
    max_pair = run_td_decoupling_model(mn_data_max_pair, build_min_cost_with_same_investments_in_all_sub_nws, optimizer; setting)
    max_import, max_export = split_result(max_pair)

    mn_data_max_base = deepcopy(mn_data)
    add_ne_branch_indicator!(mn_data_max_base, max_import) # Same investments as max_export
    add_ne_storage_indicator!(mn_data_max_base, max_import) # Same investments as max_export
    max_base = run_td_decoupling_model(mn_data_max_base, build_min_cost_with_fixed_investments, optimizer; setting)

    return ("max", max_import, max_export, max_base)
end

function intermediate_investment(mn_data, i, intermediate_cost, optimizer, setting; kwargs...)
    mn_data_1 = deepcopy(mn_data)
    mn_data_2 = deepcopy(mn_data)
    _FP.shift_nws!(mn_data_2)
    mn_data_pair = _FP.merge_multinetworks!(mn_data_1, mn_data_2, :sub_nw)
    add_max_cost!(mn_data_pair, intermediate_cost)
    pair_1 = run_td_decoupling_model(mn_data_pair, build_max_flex_band_with_bounded_cost, optimizer; setting, kwargs...)

    add_td_coupling_power_active!(mn_data_pair, pair_1)
    pair_2 = run_td_decoupling_model(mn_data_pair, build_min_cost_with_same_investments_in_all_sub_nws, optimizer; setting, kwargs...)
    i_import, i_export = split_result(pair_2)

    mn_data_base = deepcopy(mn_data)
    add_ne_branch_indicator!(mn_data_base, i_import) # Same investments as i_export
    add_ne_storage_indicator!(mn_data_base, i_import) # Same investments as i_export
    i_base = run_td_decoupling_model(mn_data_base, build_min_cost_with_fixed_investments, optimizer; setting, kwargs...)

    return ("intermediate_$i", i_import, i_export, i_base)
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
                    Memento.error(_LOGGER, "Results of flex candidate \"$name\" have different $comp investment decisions.")
                end
            end
            investment[comp] = Dict{String,Any}(ids[comp] .=> built)
        end
    end
end

function add_dist_candidates_cost!(dist_candidates::Dict{String,Any}, mn_data::Dict{String,Any})

    # Store investment cost of each network component regardless of whether it is built or not (it depends on dist candidate)
    cost_lookup = Dict{Int,Any}()
    for n in _FP.nw_ids(mn_data; hour=1, scenario=1)
        sn_data = mn_data["nw"]["$n"]
        cl_n = cost_lookup[n] = Dict{String,Any}()
        if haskey(sn_data, "ne_branch")
            cl_n_comp = cl_n["ne_branch"] = Dict{String,Float64}()
            for (i,comp) in sn_data["ne_branch"]
                cl_n_comp[i] = comp["construction_cost"]
            end
        end
        if haskey(sn_data, "ne_storage")
            cl_n_comp = cl_n["ne_storage"] = Dict{String,Float64}()
            for (i,comp) in sn_data["ne_storage"]
                cl_n_comp[i] = comp["eq_cost"] + comp["inst_cost"]
            end
        end
    end

    # Compute the cost of each dist candidate
    for candidate in values(dist_candidates)
        candidate["cost"] = sum( sum( sum( cost_lookup[n][comp_name][id] * built for (id, built) in comp_inv) for (comp_name, comp_inv) in candidate["investment"]) for n in _FP.nw_ids(mn_data; hour=1, scenario=1))
    end
end
