using JuliaDB

function get_vars(res_dict, utype, unit,
                  variables = nothing)
    name = [:time]
    value = []
    # loop through times
    for (t, tres) in res_dict["solution"]["nw"]
        row_val = Any[parse(Int64,t)]
        # get all variables for unit
        for (var,val) in tres[utype][unit]
            # add var value to row
            push!(row_val, Float64(val))
            if Symbol(var) ∉ name
                if isa(variables, Array)
                    if var ∉ variables
                        continue
                    end
                end
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

function snapshot_utype(res_dict, utype, time)
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

function get_utypes(res_dict)
    return keys(res_dict["solution"]["nw"]["1"])
end

function get_utype_vars(res_dict, utype)
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

function get_res_structure(res_dict)
    df = Dict()
    for utype in get_utypes(res_dict)
        df[utype] = []
        for var in get_utype_vars(res_dict, utype)
            push!(df[utype],var)
        end
    end
    return df
end
