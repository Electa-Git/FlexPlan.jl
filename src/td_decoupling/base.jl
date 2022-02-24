"Probe how much flexibility a distribution network can provide to transmission."
function probe_distribution_flexibility!(mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}())
    _FP.require_dim(mn_data, :sub_nw)
    if _FP.dim_length(mn_data, :sub_nw) > 1
        Memento.error(_LOGGER, "A single distribution network is required ($(dim_length(mn_data, :sub_nw)) found)")
    end

    r_base = run_td_decoupling_model(mn_data, _FP.post_simple_stoch_flex_tnep, optimizer; setting)

    add_ne_branch_indicator!(mn_data, r_base)
    add_ne_storage_indicator!(mn_data, r_base)

    r_up   = run_td_decoupling_model(mn_data, build_max_import_with_current_investments, optimizer; setting)
    r_down = run_td_decoupling_model(mn_data, build_max_export_with_current_investments, optimizer; setting)

    # Store sorted ids of components (nw, branch, etc.).
    ids = Dict{String,Any}("nw" => string.(_FP.nw_ids(mn_data)))
    first_nw = r_base["solution"]["nw"][ids["nw"][1]] # Cannot use mn_data here because it may contain inactive components
    for comp in ("branch", "ne_branch", "storage", "ne_storage")
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
    for (comp, built_keyword) in ("ne_branch"=>"built", "ne_storage"=>"isbuilt")
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
