using JuliaDB


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
    return reindex(res, real_times)
end

function get_vars(dict::Dict, utype::String, unit::String, variables::Array=[], times::Array=[])
    name = [:time]
    value = []
    # loop through times
    for (t, tres) in dict
        println(t)
        time = parse(Int64,t)
        # filter on times
        if time ∉ times && !isempty(times)
            continue
        end
        row_val = Any[time]
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

    # Add contribution from generators
    for (g, gen) in data["gen"]
        if gen["gen_bus"] == bus
            if "gen" ∉ keys(en_con)
                en_con["gen"] = Dict()
            end
            en_con["gen"][g] = Dict("pg" => 1)
        end
    end

    # Add contribution from loads
    for (l, load) in data["load"]
        if load["load_bus"] == bus
            if "load" ∉ keys(en_con)
                en_con["load"] = Dict()
            end
            en_con["load"][l] = Dict("pl" => -1)
            en_con["load"][l] = Dict("pnce" => 1)
            en_con["load"][l] = Dict("pcurt" => 1)
            en_con["load"][l] = Dict("pinter" => 1)
        end
    end

    # Add contribution from branches
    for (b, branch) in data["branch"]
        if "branch" ∉ keys(en_con)
            en_con["branch"] = Dict()
        end
        if branch["f_bus"] == bus
            en_con["branch"][b] = Dict("pt" => -1)
        elseif branch["t_bus"] == bus
            en_con["branch"][b] = Dict("pt" => 1)
        end
    end

    # Add contribution from new branches
    for (b, branch) in data["ne_branch"]
        if "ne_branch" ∉ keys(en_con)
            en_con["ne_branch"] = Dict()
        end
        if branch["f_bus"] == bus
            en_con["ne_branch"][b] = Dict("p_ne_fr" => -1)
        elseif branch["t_bus"] == bus
            en_con["ne_branch"][b] = Dict("p_ne_fr" => 1)
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
                    en_con["branchdc"][b] = Dict("pt" => -1)
                elseif branchdc["tbusdc"] == busdc
                    en_con["branchdc"][b] = Dict("pt" => 1)
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
                    en_con["branchdc_ne"][b] = Dict("pt" => -1)
                elseif branchdc_ne["tbusdc"] == busdc
                    en_con["branchdc_ne"][b] = Dict("pt" => 1)
                end
            end
        end
    end
    return en_con
end