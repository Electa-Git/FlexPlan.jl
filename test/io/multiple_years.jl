"""
    create_multi_year_network_data(case, number_of_hours, number_of_scenarios, number_of_years; <keyword arguments>)

Using the input case (`case6`, `case67`) create multi-year network data.

Dimension hierarchy is:
```
year{...
        scenario{...
            hour{...}
        }
    }
```

# Keyword arguments
- `year_scale_factor::Int=10`: how many years a representative year should represent.
- `cost_scale_factor`: scale factor for all costs (default: `1.0`).
- `sn_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  single-network dictionaries containing data for each single year, just before
  `_FP.make_multinetwork` is called. They must have exactly one argument (the single-network
  dict) and can modify it; the return value is unused.
- `kwargs...`: other parameters used by specific test cases.
"""
function create_multi_year_network_data(
        case::String,
        number_of_hours::Int,
        number_of_scenarios::Int,
        number_of_years::Int;
        year_scale_factor::Int = 10,
        cost_scale_factor::Real = 1.0,
        sn_data_extensions::Vector{<:Function} = Function[],
        kwargs...
    )
    my_data = Dict{String, Any}("multinetwork"=>true, "name"=>case, "nw"=>Dict{String,Any}(), "per_unit"=>true)
    if case == "case6"
        base_file = normpath(@__DIR__,"..","..","test","data","case6","case6_")
        planning_years = [2030, 2040, 2050]

        _FP.add_dimension!(my_data, :hour, number_of_hours)
        scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
        _FP.add_dimension!(my_data, :scenario, scenario, metadata = Dict{String,Any}("mc"=>get(kwargs, :mc, true)))
        _FP.add_dimension!(my_data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
    elseif case == "case67"
        base_file = normpath(@__DIR__,"..","..","test","data","case67","case67_tnep_")
        planning_years = [2030, 2040, 2050]

        _FP.add_dimension!(my_data, :hour, number_of_hours)
        data_years = [2017, 2018, 2019]
        start = [1483228800000, 1514764800000, 1546300800000]
        scenario = Dict(s => Dict{String,Any}(
                "probability"=>1/number_of_scenarios,
                "year" => data_years[s],
                "start" => start[s]
            ) for s in 1:number_of_scenarios)
        _FP.add_dimension!(my_data, :scenario, scenario)
        _FP.add_dimension!(my_data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
    else
        error("Case \"$(case)\" not (yet) supported.")
    end

    for year_idx = 1 : number_of_years
        year = planning_years[year_idx]
        file = base_file * "$year" * ".m"
        data = _FP.parse_file(file)
        data["dim"] = _FP.dim(my_data)
        _FP.scale_data!(data; year_idx, cost_scale_factor)

        # Apply single network data extensions
        for f! in sn_data_extensions
            f!(data)
        end

        add_one_year!(my_data, case, data, year_idx)
    end

    return my_data
end

function add_one_year!(my_data, case, data, year_idx)
    number_of_nws = _FP.dim_length(data, :hour) * _FP.dim_length(data, :scenario)
    nw_id_offset = number_of_nws * (year_idx - 1)
    if case == "case6"
        data, loadprofile, genprofile = create_profile_data_italy!(data)
    elseif case == "case67"
        data, loadprofile, genprofile = create_profile_data_germany!(data)
    else
        error("Case \"$(case)\" not (yet) supported.")
    end
    time_series = create_profile_data(number_of_nws, data, loadprofile, genprofile)
    mn_data = _FP.make_multinetwork(data, time_series; number_of_nws, nw_id_offset)
    _FP.import_nws!(my_data, mn_data)
    return my_data
end
