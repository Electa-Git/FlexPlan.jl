"""
    create_multi_year_network_data(case, number_of_hours, number_of_scenarios, number_of_years)

    Using the input case (case6, cigre, ...) create multi-year network data using the add_dimensions!(...).

    Dimension hierarchy is:
    year{...
        scenario{...
            hour{...}
        }
    }

"""
function create_multi_year_network_data(case, number_of_hours, number_of_scenarios, number_of_years)
    if case == "case6"
        base_file = "./test/data/multiple_years/case6/t_case6_"
        planning_years = [2030 2040 2050]
        year_scale_factor = 10
        my_data = Dict{String, Any}()
        for idx = 1 : number_of_years
            year = planning_years[idx]
            file = join([base_file,"$year",".m"])
            data = _FP.parse_file(file)
            data = add_hours_and_scenarios!(data, case, number_of_hours, number_of_scenarios, year_scale_factor)
            if idx == 1
                _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
                my_data = data
            else
                my_data = add_year!(my_data, data)
            end
        end
    elseif case == "case67"
        base_file = "./test/data/multiple_years/case67/case67_tnep_"
        planning_years = [2030 2040 2050]
        year_scale_factor = 10
        my_data = Dict{String, Any}()
        for idx = 1 : number_of_years
            year = planning_years[idx]
            file = join([base_file,"$year",".m"])
            data = _FP.parse_file(file)
            data = add_hours_and_scenarios!(data, case, number_of_hours, number_of_scenarios, year_scale_factor)
            if idx == 1
                _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
                my_data = data
            else
                my_data = add_year!(my_data, data)
            end
        end
    else
        error("Case \"$(case)\" not (yet) supported.")
    end
    return my_data
end

function add_hours_and_scenarios!(data, case, number_of_hours, number_of_scenarios, year_scale_factor; kwargs...)
    if case == "case6"
        _FP.add_dimension!(data, :hour, number_of_hours)

        scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
        _FP.add_dimension!(data, :scenario, scenario, metadata = Dict{String,Any}("mc"=>get(kwargs, :mc, true)))

        _FP.scale_data!(data; year_scale_factor)
        data, loadprofile, genprofile = create_profile_data_italy!(data)
        extradata = _FP.create_profile_data(number_of_hours*number_of_scenarios, data, loadprofile, genprofile)
        data = _FP.multinetwork_data(data, extradata)
    elseif case == "case67"
        _FP.add_dimension!(data, :hour, number_of_hours)

        scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
        # metadata = Dict{String,Any}("mc"=>mc)
        years = [2017, 2018, 2019]
        start = [1483228800000, 1514764800000, 1546300800000]
        # metadata["sc_years"] = Dict{String, Any}()
        for s in 1:number_of_scenarios
            scenario[s]["year"] = years[s]
            scenario[s]["start"] = start[s]
        end
        _FP.add_dimension!(data, :scenario, scenario)
        _FP.scale_data!(data; year_scale_factor)
        data, loadprofile, genprofile = create_profile_data_germany!(data)
        extradata = _FP.create_profile_data(number_of_hours*number_of_scenarios, data, loadprofile, genprofile)
        data = _FP.multinetwork_data(data, extradata)
    else
        error("Case \"$(case)\" not (yet) supported.")
    end
    return data
end

function add_year!(my_data::Dict{String, Any}, data::Dict{String, Any})
    number_of_networks = length(my_data["nw"])
    for (nw, network) in data["nw"]
        nw_id = parse(Int, nw) + number_of_networks
        my_data["nw"]["$nw_id"] = network
    end
    return my_data
end
