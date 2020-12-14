function add_storage_data!(data)
    for (s, storage) in data["storage"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(storage, "max_energy_absorption", rescale_power)
        _PM._apply_func!(storage, "stationary_energy_outflow", rescale_power)
        _PM._apply_func!(storage, "stationary_energy_inflow", rescale_power)
    end

    for (s, storage) in data["ne_storage"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(storage, "energy_rating", rescale_power)
        _PM._apply_func!(storage, "thermal_rating", rescale_power)
        _PM._apply_func!(storage, "discharge_rating", rescale_power)
        _PM._apply_func!(storage, "charge_rating", rescale_power)
        _PM._apply_func!(storage, "energy", rescale_power)
        _PM._apply_func!(storage, "ps", rescale_power)
        _PM._apply_func!(storage, "qs", rescale_power)
        _PM._apply_func!(storage, "q_loss", rescale_power)
        _PM._apply_func!(storage, "p_loss", rescale_power)
        _PM._apply_func!(storage, "qmax", rescale_power)
        _PM._apply_func!(storage, "qmin", rescale_power)
        _PM._apply_func!(storage, "max_energy_absorption", rescale_power)
        _PM._apply_func!(storage, "stationary_energy_outflow", rescale_power)
        _PM._apply_func!(storage, "stationary_energy_inflow", rescale_power)
    end
    return data
end

function scale_cost_data!(data, scenario)
    for (g, gen) in data["gen"]
        gen["cost"] = gen["cost"] * 8760 / scenario["hours"] * scenario["planning_horizon"] # scale hourly costs to the planning horizon
    end
    for (b, branch) in data["ne_branch"]
        branch["construction_cost"] = branch["construction_cost"] / scenario["hours"]  # construction cost is given as total cost
        if haskey(branch, "co2_cost")
            branch["co2_cost"] = branch["co2_cost"] / scenario["hours"]  # co2 cost is given as total cost
        end
    end
    for (b, branch) in data["branchdc_ne"]
        branch["cost"] = branch["cost"] / scenario["hours"]  # construction cost is given as total cost
        if haskey(branch, "co2_cost")
            branch["co2_cost"] = branch["co2_cost"] / scenario["hours"]  # co2 cost is given as total cost
        end
    end
    for (c, conv) in data["convdc_ne"]
        conv["cost"] = conv["cost"] / scenario["hours"]  # construction cost is given as total cost
        if haskey(conv, "co2_cost")
            conv["co2_cost"] = conv["co2_cost"] / scenario["hours"]  # co2 cost is given as total cost
        end
    end
    for (s, strg) in data["ne_storage"]
        strg["eq_cost"] = strg["eq_cost"] / scenario["hours"]  # equipment cost is given as total cost
        strg["inst_cost"] = strg["inst_cost"] / scenario["hours"]  # installation cost is given as total cost
        if haskey(strg, "co2_cost")
            strg["co2_cost"] = strg["co2_cost"] / scenario["hours"]  # co2 cost is given as total cost
        end
    end
    for (l, load) in data["load"]
        load["cost_investment"] = load["cost_investment"] / scenario["hours"]  # investment cost is given as total cost
        load["cost_shift_up"] = load["cost_shift_up"] * 8760 / scenario["hours"] * scenario["planning_horizon"] # scale hourly costs to the planning horizon
        load["cost_shift_down"] = load["cost_shift_down"]* 8760 / scenario["hours"] * scenario["planning_horizon"] # scale hourly costs to the planning horizon
        load["cost_curtailment"] = load["cost_curtailment"]* 8760 / scenario["hours"] * scenario["planning_horizon"] # scale hourly costs to the planning horizon
        load["cost_reduction"] = load["cost_reduction"]* 8760 / scenario["hours"] * scenario["planning_horizon"] #
        if haskey(load, "co2_cost")
            load["co2_cost"] = load["co2_cost"] / scenario["hours"]  # co2 cost is given as total cost
        end
    end
    if haskey(data, "emission_cost")
        data["emission_cost"] = data["emission_cost"] * 8760 / scenario["hours"] * scenario["planning_horizon"] # scale hourly costs to the planning horizon
    end
end

function add_flexible_demand_data!(data)
    for (le, load_extra) in data["load_extra"]
        idx = load_extra["load_id"]
        data["load"]["$idx"]["p_red_max"] = load_extra["p_red_max"]
        data["load"]["$idx"]["p_red_min"] = load_extra["p_red_min"]
        data["load"]["$idx"]["p_shift_up_max"] = load_extra["p_shift_up_max"]
        data["load"]["$idx"]["p_shift_up_tot_max"] = load_extra["p_shift_up_tot_max"]
        data["load"]["$idx"]["p_shift_down_max"] = load_extra["p_shift_down_max"]
        data["load"]["$idx"]["p_shift_down_tot_max"] = load_extra["p_shift_down_tot_max"]
        data["load"]["$idx"]["cost_reduction"] = load_extra["cost_reduction"]
        data["load"]["$idx"]["t_grace_up"] = load_extra["t_grace_up"]
        data["load"]["$idx"]["t_grace_down"] = load_extra["t_grace_down"]
        data["load"]["$idx"]["cost_shift_up"] = load_extra["cost_shift_up"]
        data["load"]["$idx"]["cost_shift_down"] = load_extra["cost_shift_down"]
        data["load"]["$idx"]["cost_curtailment"] = load_extra["cost_curt"]
        data["load"]["$idx"]["cost_investment"] = load_extra["cost_inv"]
        data["load"]["$idx"]["flex"] = load_extra["flex"]
        data["load"]["$idx"]["e_nce_max"] = load_extra["e_nce_max"]
        if haskey(load_extra, "co2_cost")
            data["load"]["$idx"]["co2_cost"] = load_extra["co2_cost"]
        end
        rescale_cost = x -> x*data["baseMVA"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(data["load"]["$idx"], "cost_reduction", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up_tot_max", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down_tot_max", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_curtailment", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "e_nce_max", rescale_power)
    end
    delete!(data, "load_extra")
    return data
end

function add_generation_emission_data!(data)
    for (e, em) in data["generator_emission_factors"]
        idx = em["gen_id"]
        data["gen"]["$idx"]["emission_factor"] = em["emission_factor"]
        rescale_emission = x -> x * data["baseMVA"]
        _PM._apply_func!(data["gen"]["$idx"], "emission_factor", rescale_emission)
    end
    delete!(data, "load_extra")
    return data
end

function create_profile_data(number_of_hours, data, loadprofile = ones(length(data["load"]), number_of_hours), genprofile = ones(length(data["gen"]), number_of_hours))
    extradata = Dict{String,Any}()
    extradata["dim"] = Dict{String,Any}()
    extradata["dim"] = number_of_hours
    extradata["load"] = Dict{String,Any}()
    extradata["gen"] = Dict{String,Any}()
    for (l, load) in data["load"]
        extradata["load"][l] = Dict{String,Any}()
        extradata["load"][l]["pd"] = Array{Float64,2}(undef, 1, number_of_hours)
        for d in 1:number_of_hours
            extradata["load"][l]["pd"][1, d] = data["load"][l]["pd"] * loadprofile[parse(Int, l), d]
        end
    end

    for (g, gen) in data["gen"]
        extradata["gen"][g] = Dict{String,Any}()
        extradata["gen"][g]["pmax"] = Array{Float64,2}(undef, 1, number_of_hours)
        for d in 1:number_of_hours
            extradata["gen"][g]["pmax"][1, d] = data["gen"][g]["pmax"] * genprofile[parse(Int, g), d]
        end
    end

    return extradata
end

function create_profile_data_italy(data, scenario = Dict{String, Any}())

    genprofile = ones(length(data["gen"]), length(scenario["sc_years"]) * scenario["hours"])
    loadprofile = ones(length(data["load"]), length(scenario["sc_years"]) * scenario["hours"])

    data["scenario"] = Dict{String, Any}()
    data["scenario_prob"] = Dict{String, Any}()

    if haskey(scenario, "mc")
        monte_carlo = scenario["mc"]
    else
        monte_carlo = false
    end

    for (s, scnr) in scenario["sc_years"]
        year = scnr["year"]
        pv_sicily, pv_south_central, wind_sicily = read_res_data(year; mc = monte_carlo)
        demand_center_north_pu, demand_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu = read_demand_data(year; mc = monte_carlo)

        start_idx = (parse(Int, s) - 1) * scenario["hours"]
        if monte_carlo == false
            for h in 1 : scenario["hours"]
                h_idx = scnr["start"] + ((h-1) * 3600000)
                genprofile[3, start_idx + h] = pv_south_central["data"]["$h_idx"]["electricity"]
                genprofile[5, start_idx + h] = pv_sicily["data"]["$h_idx"]["electricity"]
                genprofile[6, start_idx + h] = wind_sicily["data"]["$h_idx"]["electricity"]
            end
        else
            genprofile[3, start_idx + 1 : start_idx + scenario["hours"]] = pv_south_central[1: scenario["hours"]]
            genprofile[5, start_idx + 1 : start_idx + scenario["hours"]] = pv_sicily[1: scenario["hours"]]
            genprofile[6, start_idx + 1 : start_idx + scenario["hours"]] = wind_sicily[1: scenario["hours"]]
        end
        loadprofile[:, start_idx + 1 : start_idx + scenario["hours"]] = [demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1: scenario["hours"]]
        # loadprofile[:, start_idx + 1 : start_idx + scenario["hours"]] = repeat([demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1],1,scenario["hours"])

        data["scenario"][s] = Dict()
        data["scenario_prob"][s] = scnr["probability"]
        for h in 1 : scenario["hours"]
            network = start_idx + h
            data["scenario"][s]["$h"] = network
        end

    end
    # Add bus loactions to data dictionary
    data["bus"]["1"]["lat"] = 43.4894; data["bus"]["1"]["lon"] =  11.7946; #Italy central north
    data["bus"]["2"]["lat"] = 45.3411; data["bus"]["2"]["lon"] =  9.9489;  #Italy north
    data["bus"]["3"]["lat"] = 41.8218; data["bus"]["3"]["lon"] =   13.8302; #Italy central south
    data["bus"]["4"]["lat"] = 40.5228; data["bus"]["4"]["lon"] =   16.2155; #Italy south
    data["bus"]["5"]["lat"] = 40.1717; data["bus"]["5"]["lon"] =   9.0738; # Sardinia
    data["bus"]["6"]["lat"] = 37.4844; data["bus"]["6"]["lon"] =   14.1568; # Sicily
    # Return info
    return data, loadprofile, genprofile
end

function create_profile_data_norway(data, number_of_hours)
# creates load and generation profiles from Norway data
# - for now generation profile is constant at 1.0
# - for now works only for single scenario

    demand_data = CSV.read("./test/data/demand_Norway_2015.csv")
    demand = demand_data[:,2:end]
    n_hours_data = size(demand,1)
    n_loads_data = size(demand,2)
    demand_pu = zeros(n_hours_data,n_loads_data)
    for i_load_data = 1:n_loads_data
          demand_pu[:,i_load_data] = demand[:,i_load_data] ./ maximum(demand[:,i_load_data])
    end
    loadprofile = demand_pu[1:number_of_hours,1:length(data["load"])]'
    # for now gen profile is constant
    genprofile = ones(length(data["gen"]), number_of_hours)

    return data,loadprofile,genprofile
end
