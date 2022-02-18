## Result - data structure interaction

# These functions allow to pass investment decisions between two problems: the investment
# decision results of the first problem are copied into the data structure of the second
# problem; an appropriate constraint may be necessary in the model of the second problem to
# read the data prepared by these functions.

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

function add_td_coupling_power_active!(mn_data::Dict{String,Any}, result::Dict{String,Any})
    for (n, data_nw) in mn_data["nw"]
        p = result["solution"]["nw"][n]["td_coupling"]["p"]
        d_gen_id = _FP.dim_prop(mn_data, parse(Int,n), :sub_nw, "d_gen")
        d_gen = data_nw["gen"]["$d_gen_id"] = deepcopy(data_nw["gen"]["$d_gen_id"]) # Gen data is shared among nws originally.
        d_gen["pmax"] = p
        d_gen["pmin"] = p
    end
end
