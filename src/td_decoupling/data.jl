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
