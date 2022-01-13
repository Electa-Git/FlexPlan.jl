using JuliaDB
using Statistics

function get_data(data_dict::Dict, utype::String, unit::String,
    variables::Array = [])
    return get_vars(data_dict["nw"], utype, unit, variables)
end

function get_res(res_dict::Dict, utype::String, unit::String,
    variables::Array = [])
    return get_vars(res_dict["solution"]["nw"], utype, unit, variables)
end

function get_res(res_dict::Dict, utype::String, unit::String,
    variables::String)
    return get_vars(res_dict["solution"]["nw"], utype, unit, [variables])
end

function get_res(res_dict::Dict, scen_dict::Dict, utype::String, unit::String,
                 variable::String)
    res = select(get_res(res_dict, utype, unit, variable), Symbol(variable))
    scen_names = collect(keys(scen_dict))
    n_time = length(values(scen_dict[scen_names[1]]))
    scen_res = zeros(length(scen_dict), n_time)
    scen_times = [1:n_time]
    for (s, scenario) in scen_dict
        scen_times = sort([parse(Int,i[1]) for i in scenario])
        times = sort([i[2] for i in scenario])
        scen_res[parse(Int,s)+1,scen_times] = res[times]
    end
    return (scen_times, scen_res)
end


function get_scenario_res(res_dict::Dict, scen_dict::Dict, scenario::String, utype::String, unit::String, variables::Array=[])
    scen_times = sort(collect(values(scen_dict[scenario])))
    res = get_vars(res_dict["solution"]["nw"], utype, unit, variables, scen_times)
    real_times = sort([parse(Int64,i) for i in keys(scen_dict[scenario])])
    if isempty(res)
        return res
    else
        return reindex(res, real_times)
    end
end

function get_scenario_data(mn_data::Dict, scen_dict::Dict, scenario::String, utype::String, unit::String, variables::Array=[])
    scen_times = sort(collect(values(scen_dict[scenario])))
    res = get_vars(mn_data["nw"], utype, unit, variables, scen_times)
    real_times = sort([parse(Int64,i) for i in keys(scen_dict[scenario])])
    if isempty(res)
        return res
    else
        return reindex(res, real_times)
    end
end

function get_vars(dict::Dict, utype::String, unit::String, variables::Array=[], times::Array=[])
    name = [:time]
    value = []
    # loop through times
    for (t, tres) in dict
        time = parse(Int64,t)
        # filter on times
        if time ∉ times && !isempty(times)
            continue
        end
        row_val = Any[time]
        if utype ∉ keys(tres)
            continue
        end
        # get all variables for unit
        if unit in keys(tres[utype])
            for (var,val) in tres[utype][unit]
                # filter on variables
                if (var ∉ variables && !isempty(variables)) || isa(val, Array)
                    continue
                else
                    # add var value to row
                    push!(row_val, Float64(val))
                end
                if Symbol(var) ∉ name
                    # add var names to header
                    push!(name, Symbol(var))
                end
            end
        else # if unit is not in results, return NaN for all variables
            for var in name
                # add var value to row
                push!(row_val, NaN)
            end
        end
        # add row to table
        push!(value, (; zip(name,row_val)...))
    end
    # return sorted table
    return sort(table([i for i in value]))
end

function snapshot_utype(res_dict::Dict, utype::String, time::Int)
    name = [:unit]
    value = []
    # loop through units of utype
    for (unit, vars) in res_dict["solution"]["nw"][string(time)][utype]
        row_val = Any[parse(Int64,unit)]
        # get all variables for unit
        for (var, val) in vars
            # add var value to row
            push!(row_val, Float64(val))
            if Symbol(var) ∉ name
                # add var names to header
                push!(name, Symbol(var))
            end
        end
        # add row to table
        push!(value, (; zip(name,row_val)...))
    end
    # return sorted table
    return sort(table([i for i in value]))
end

function get_utypes(res_dict::Dict)
    return keys(res_dict["solution"]["nw"]["1"])
end

function get_utype_vars(res_dict::Dict, utype::String)
    uvars = Any[]
    unit_dict = res_dict["solution"]["nw"]["1"][utype]

    if ~isa(unit_dict, Dict)
        return []
    end

    for (unit, vars) in unit_dict
        unit_vars = keys(vars)
        for v in unit_vars
            if v ∉ uvars
                push!(uvars, v)
            end
        end
    end
    return uvars
end

function get_res_structure(res_dict::Dict)
    df = Dict()
    for utype in get_utypes(res_dict)
        df[utype] = []
        for var in get_utype_vars(res_dict, utype)
            push!(df[utype],var)
        end
    end
    return df
end

function get_energy_contribution_at_bus(data::Dict, bus::Int)

    en_con = Dict()
    enbal_contr = Dict("gen" => Dict("gen_bus" => Dict("pg" => 1
                                       )
                        ),
         "load" => Dict("load_bus" =>Dict("pl" =>-1,
                                      #"pflex" => -1,
                                      "pd" => -1,
                                      "pred" => 1,
                                      "pcurt" => 1,
                                      "pinter" => 1,
                                      "pshift_up" => -1,
                                      "pshift_down" => 1
                                     )
                        ),
         "branch" => Dict("f_bus" => Dict("pf"=> -1),
                          "t_bus" => Dict("pt"=> -1)
                            ),
         "ne_branch" => Dict("f_bus" => Dict("p_ne_fr" => -1),
                             "t_bus" => Dict("p_ne_to" => -1)
                            ),
         "storage" => Dict("storage_bus" => Dict("sc" => -1,
                                                 "sd" => 1)
                            ),
         "ne_storage" => Dict("storage_bus" => Dict("sc_ne" => -1,
                                                    "sd_ne" => 1)
                             )
        )
    # Add contribution from units
    for (utype, contr_dict) in enbal_contr
        for (u, unit) in data[utype]
            for (bus_id, vars) in contr_dict
                if unit[bus_id] == bus
                    if utype ∉ keys(en_con)
                        en_con[utype] = Dict()
                    end
                    en_con[utype][u] = vars
                end
            end
        end
    end

    # Add contribution from DC branches connected through converters
    for (c, convdc) in data["convdc"]
        if convdc["busac_i"] == bus
            busdc = convdc["busdc_i"]
            for (b, branchdc) in data["branchdc"]
                if "branchdc" ∉ keys(en_con)
                    en_con["branchdc"] = Dict()
                end
                if branchdc["fbusdc"] == busdc
                    en_con["branchdc"][b] = Dict("pf" => -1)
                elseif branchdc["tbusdc"] == busdc
                    en_con["branchdc"][b] = Dict("pt" => -1)
                end
            end
        end
    end
    # Add contribution from new DC branches connected through converters
    for (c, convdc) in data["convdc_ne"]
        if convdc["busac_i"] == bus
            busdc = convdc["busdc_i"]
            for (b, branchdc_ne) in data["branchdc_ne"]
                if "branchdc_ne" ∉ keys(en_con)
                    en_con["branchdc_ne"] = Dict()
                end
                if branchdc_ne["fbusdc"] == busdc
                    en_con["branchdc_ne"][b] = Dict("pf" => -1)
                elseif branchdc_ne["tbusdc"] == busdc
                    en_con["branchdc_ne"][b] = Dict("pt" => -1)
                end
            end
        end
    end
    return en_con
end

function get_scenario_inv(result, scen_times)
    temp_res = Dict()
    units = Dict()
    for s in keys(scen_times)
        temp_res[s] = Dict()
        for utype in get_utypes(result)
            vars = get_utype_vars(result,utype)
            if "built" in vars
                build_str = "built"
            elseif "isbuilt" in vars
                build_str = "isbuilt"
            else
                continue
            end
            temp_res[s][Symbol(utype)] = OrderedDict()
            if length(keys(result["solution"]["nw"]["1"][utype])) > 0
                units[utype] = sort!(collect(keys(result["solution"]["nw"]["1"][utype])))
                for unit in units[utype]
                    res = get_scenario_res(result, scen_times, s, utype, unit, [build_str])
                    val = mean(select(res,3))
                    #temp_res[s][utype][unit] = val
                    temp_res[s][Symbol(utype)][unit] = val
                end
            end
        end
    end
    # Create table from dict
    res = Dict()
    for (scen, sres) in temp_res
        res[scen] = OrderedDict{Symbol,AbstractVector}()
        max_length = maximum([length(i) for i in values(sres)])
        for (utype, unit_dict) in sres
            res[scen][utype] = []
            for i in range(1,stop = max_length)
                i_str = string(i)
                if i_str ∉ keys(unit_dict)
                    append!(res[scen][utype], NaN)
                else
                    append!(res[scen][utype], unit_dict[i_str])
                end
            end
        end
        cols = [:unit]
        append!(cols, keys(sres))
        res[scen][:unit] = collect(1:max_length)
        res[scen] = select(table(res[scen]), tuple(cols...))
    end
    return res
end