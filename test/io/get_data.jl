using JuliaDB

function get_data(data::Dict, utype::String)

    name = [:unit]
    value = []
    # loop through units of utype
    for (unit, vars) in data[utype]
        row_val = Any[parse(Int64,unit)]
        # get all parameters for unit
        for (var, val) in vars
            # add var value to row
            if isa(val, Array)
                val = join(string.(val),", ")
                push!(row_val, val)
            else
                push!(row_val, Float64(val))
            end
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