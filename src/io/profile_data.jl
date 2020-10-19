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

function add_flexible_demand_data!(data)
    for (le, load_extra) in data["load_extra"]
        idx = load_extra["load_id"]
        data["load"]["$idx"]["p_red_max"] = load_extra["p_red_max"]
        data["load"]["$idx"]["p_red_min"] = load_extra["p_red_min"]
        data["load"]["$idx"]["p_shift_up_max"] = load_extra["p_shift_up_max"]
        data["load"]["$idx"]["p_shift_up_min"] = load_extra["p_shift_up_min"]
        data["load"]["$idx"]["p_shift_down_max"] = load_extra["p_shift_down_max"]
        data["load"]["$idx"]["p_shift_down_min"] = load_extra["p_shift_down_min"]
        data["load"]["$idx"]["cost_reduction"] = load_extra["cost_reduction"]
        data["load"]["$idx"]["t_grace_up"] = load_extra["t_grace_up"]
        data["load"]["$idx"]["t_grace_down"] = load_extra["t_grace_down"]
        data["load"]["$idx"]["cost_shift_up"] = load_extra["cost_shift_up"]
        data["load"]["$idx"]["cost_shift_down"] = load_extra["cost_shift_down"]
        data["load"]["$idx"]["cost_curtailment"] = load_extra["cost_curt"]
        data["load"]["$idx"]["cost_investment"] = load_extra["cost_inv"]
        data["load"]["$idx"]["flex"] = load_extra["flex"]
        data["load"]["$idx"]["e_nce_max"] = load_extra["e_nce_max"]
        rescale_cost = x -> x*data["baseMVA"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(data["load"]["$idx"], "cost_reduction", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_curtailment", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "e_nce_max", rescale_power)
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

function create_profile_data_italy(data, start_hour, number_of_hours)
    # Read in renewable generation and demand profile data
    pv_sicily = Dict()
    open("./test/data/pv_sicily.json") do f
        dicttxt = read(f, String)  # file information to string
        pv_sicily = JSON.parse(dicttxt)  # parse and transform data
    end
    pv_south_central = Dict()
    open("./test/data/pv_south_central.json") do f
        dicttxt = read(f, String)  # file information to string
        pv_south_central = JSON.parse(dicttxt)  # parse and transform data
    end

    wind_sicily = Dict()
    open("./test/data/wind_sicily.json") do f
        dicttxt = read(f, String)  # file information to string
        wind_sicily = JSON.parse(dicttxt)  # parse and transform data
    end

    # Read in demand data
    demand_north = convert(Matrix, CSV.read("./test/data/demand_north.csv"))[:,3]
    demand_center_north = convert(Matrix, CSV.read("./test/data/demand_center_north.csv"))[:,3]
    demand_center_south = convert(Matrix, CSV.read("./test/data/demand_center_south.csv"))[:,3]
    demand_south = convert(Matrix, CSV.read("./test/data/demand_south.csv"))[:,3]
    demand_sardinia = convert(Matrix, CSV.read("./test/data/demand_sardinia.csv"))[:,3]

    # Convert demand_profile to pu of maxximum
    demand_north_pu = demand_north ./ maximum(demand_north)
    demand_center_north_pu = demand_center_north ./ maximum(demand_center_north)
    demand_south_pu = demand_south ./ maximum(demand_south)
    demand_center_south_pu = demand_center_south ./ maximum(demand_center_south)
    demand_sardinia_pu = demand_sardinia ./ maximum(demand_sardinia)

    # Write generation and loadprofiles based on number of hours specified 
    genprofile = ones(length(data["gen"]), number_of_hours)
    for h in 1 : number_of_hours
        h_idx = start_hour + ((h-1) * 3600000)
        genprofile[3, h] = pv_south_central["data"]["$h_idx"]["electricity"]
        genprofile[5, h] = pv_sicily["data"]["$h_idx"]["electricity"]
        genprofile[6, h] = wind_sicily["data"]["$h_idx"]["electricity"]
    end
    loadprofile = [demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1: number_of_hours]

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
