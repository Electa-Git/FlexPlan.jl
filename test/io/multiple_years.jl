"""
    create_multi_year_network_data(case, number_of_hours, number_of_scenarios, number_of_years)
    
    Using the input case (case6, cigre, ...) create multi-year network data using the add_dimentions!(...). 

    Dimension hierarchy is: 
    year{...
        scenario{...
            hour{...}
        }
    }

"""
function create_multi_year_network_data(case, number_of_hours, number_of_scenarios, number_of_years, planning_horizon)   
    if case == "case6"
        ## Test case preparation
        base_file = "./test/data/multiple_years/case6/t_case6_"
        planning_years = [2030 2040 2050]
        my_data = Dict{String, Any}()
        for idx = 1 : number_of_years 
            year = planning_years[idx]
            file = join([base_file,"$year",".m"])
            data = _FP.parse_file(file)
            data = add_hours_and_scenarios(data, number_of_hours, number_of_scenarios, planning_horizon)
            if idx == 1
                _FP.add_dimension!(data, :year, number_of_years)
                my_data = data
            else
                my_data = add_year(my_data, data)
            end
        end
    else
        error(join([case, " not (yet) supported"]))
    end
    return my_data
end

function add_hours_and_scenarios(case, data, number_of_hours, number_of_scenarios, planning_horizon)
        _FP.add_dimension!(data, :hour, number_of_hours)

        scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
        _FP.add_dimension!(data, :scenario, scenario, metadata = Dict{String,Any}("mc"=>true))

        _FP.scale_cost_data!(data, planning_horizon)
        data, loadprofile, genprofile = create_profile_data_italy!(data)
        extradata = _FP.create_profile_data(number_of_hours*number_of_scenarios, data, loadprofile, genprofile)
        data = _FP.multinetwork_data(data, extradata)
    return data
end

function add_year(my_data::Dict{String, Any}, data::Dict{String, Any})
    number_of_networks = length(my_data["nw"])
    for (nw, network) in data["nw"]
        nw_id = parse(Int, nw) + number_of_networks
        my_data["nw"]["$nw_id"] = network
    end
    return my_data
end