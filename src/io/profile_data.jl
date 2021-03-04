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
    rescale_hourly = x -> (8760*scenario["planning_horizon"] / scenario["hours"]) * x # scale hourly costs to the planning horizon
    rescale_total  = x -> (                                1 / scenario["hours"]) * x # scale total costs to the planning horizon
    for (g, gen) in data["gen"]
        _PM._apply_func!(gen, "cost", rescale_hourly)
    end
    for (b, branch) in get(data, "ne_branch", Dict{String,Any}())
        _PM._apply_func!(branch, "construction_cost", rescale_total)
        _PM._apply_func!(branch, "co2_cost", rescale_total)
    end
    for (b, branch) in get(data, "branchdc_ne", Dict{String,Any}())
        _PM._apply_func!(branch, "cost", rescale_total)
        _PM._apply_func!(branch, "co2_cost", rescale_total)
    end
    for (c, conv) in get(data, "convdc_ne", Dict{String,Any}())
        _PM._apply_func!(conv, "cost", rescale_total)
        _PM._apply_func!(conv, "co2_cost", rescale_total)
    end
    for (s, strg) in get(data, "ne_storage", Dict{String,Any}())
        _PM._apply_func!(strg, "eq_cost", rescale_total)
        _PM._apply_func!(strg, "inst_cost", rescale_total)
        _PM._apply_func!(strg, "co2_cost", rescale_total)
    end
    for (l, load) in data["load"]
        _PM._apply_func!(load, "cost_shift_up", rescale_hourly)
        _PM._apply_func!(load, "cost_shift_down", rescale_hourly)
        _PM._apply_func!(load, "cost_curtailment", rescale_hourly)
        _PM._apply_func!(load, "cost_reduction", rescale_hourly)
        _PM._apply_func!(load, "cost_investment", rescale_total)
        _PM._apply_func!(load, "co2_cost", rescale_total)
    end
    _PM._apply_func!(data, "co2_emission_cost", rescale_hourly)
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
        if haskey(load_extra, "cost_voll")
            data["load"]["$idx"]["cost_voll"] = load_extra["cost_voll"]
        end
        if haskey(load_extra, "co2_cost")
            data["load"]["$idx"]["co2_cost"] = load_extra["co2_cost"]
        end
        if haskey(load_extra, "pf_angle")
            data["load"]["$idx"]["pf_angle"] = load_extra["pf_angle"]
        end
        rescale_cost = x -> x*data["baseMVA"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(data["load"]["$idx"], "cost_reduction", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up_tot_max", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down_tot_max", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_curtailment", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_voll", rescale_cost)
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

function create_profile_data(number_of_hours, data, loadprofile = ones(length(data["load"]), number_of_hours),
                             genprofile = ones(length(data["gen"]), number_of_hours))
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

function create_contingency_data(number_of_hours, data, contingency_profiles=Dict(), loadprofile = ones(length(data["load"]), number_of_hours),
    genprofile = ones(length(data["gen"]), number_of_hours))
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

    for (utype, profiles) in contingency_profiles
        extradata[utype] = Dict{String,Any}()
        for (u, unit) in data[utype]
            extradata[utype][u] = Dict{String,Any}()
            if "br_status" in keys(unit)
                state_str = "br_status"
            elseif "status" in keys(unit)
                state_str = "status"
            end
            if "rate_a" in keys(unit)
                rate_str = "rate_a"
            else "rateA" in keys(unit)
                rate_str = "rateA"
            end
            rate = unit[rate_str]
            extradata[utype][u][state_str] = Array{Float64,2}(undef, 1, number_of_hours)
            extradata[utype][u][rate_str] = Array{Float64,2}(undef, 1, number_of_hours)
            for d in 1:number_of_hours
                state = profiles[parse(Int, u), d]
                extradata[utype][u][state_str][1, d] = state
                extradata[utype][u][rate_str][1, d] = state*rate
            end
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

function create_contingency_data_italy(data, scenario = Dict{String, Any}())


    genprofile = ones(length(data["gen"]), length(scenario["contingency"]) * scenario["hours"])
    loadprofile = ones(length(data["load"]), length(scenario["contingency"]) * scenario["hours"])

    contingency_profiles = Dict{String,Any}()
    for t in scenario["utypes"]
        contingency_profiles[t] = ones(length(data[t]), length(scenario["contingency"]) * scenario["hours"])
    end
    
    data["contingency"] = Dict{String, Any}()
    data["contingency_prob"] = Dict{String, Any}()

    for (s, scnr) in scenario["contingency"]
        year = scnr["year"]
        pv_sicily, pv_south_central, wind_sicily = read_res_data(year)
        demand_center_north_pu, demand_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu = read_demand_data(year)

        data["contingency"][s] = Dict()
        data["contingency_prob"][s] = scnr["probability"]
        
        start_idx = parse(Int, s)*scenario["hours"]
        for (unit_type, units) in scnr["faults"]
            for u in units
                for h in 1 : scenario["hours"]
                    contingency_profiles[unit_type][u, start_idx + h] = 0
                end
            end
        end

        for h in 1 : scenario["hours"]
            network = start_idx + h
            data["contingency"][s]["$h"] = network

            h_idx = scnr["start"] + ((h-1) * 3600000)
            genprofile[3, start_idx + h] = pv_south_central["data"]["$h_idx"]["electricity"]
            genprofile[5, start_idx + h] = pv_sicily["data"]["$h_idx"]["electricity"]
            genprofile[6, start_idx + h] = wind_sicily["data"]["$h_idx"]["electricity"]
        end

        loadprofile[:, start_idx + 1 : start_idx + scenario["hours"]] = [demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1: scenario["hours"]]
    end
    # Add bus loactions to data dictionary
    data["bus"]["1"]["lat"] = 43.4894; data["bus"]["1"]["lon"] =  11.7946; #Italy central north
    data["bus"]["2"]["lat"] = 45.3411; data["bus"]["2"]["lon"] =  9.9489;  #Italy north
    data["bus"]["3"]["lat"] = 41.8218; data["bus"]["3"]["lon"] =   13.8302; #Italy central south
    data["bus"]["4"]["lat"] = 40.5228; data["bus"]["4"]["lon"] =   16.2155; #Italy south
    data["bus"]["5"]["lat"] = 40.1717; data["bus"]["5"]["lon"] =   9.0738; # Sardinia
    data["bus"]["6"]["lat"] = 37.4844; data["bus"]["6"]["lon"] =   14.1568; # Sicily
    # Return info
    return data, contingency_profiles, loadprofile, genprofile
end

function create_profile_data_norway(data, number_of_hours)
# creates load and generation profiles from Norway data
# - for now generation profile is constant at 1.0
# - for now works only for single scenario

    demand_data = CSV.read("./test/data/demand_Norway_2015.csv", DataFrames.DataFrame)
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

"Creates load and generation profiles for CIGRE distribution network from Italy data"
function create_profile_data_cigre_italy(data, number_of_hours; scale_load = 1.0, scale_gen = 1.0)

    ## Fixed parameters

    file_load_ind    = "./test/data/CIGRE_industrial_loads.csv"
    file_load_res    = "./test/data/CIGRE_residential_loads.csv"
    file_profiles_pu = "./test/data/CIGRE_profiles_per_unit.csv"
    scale_unit       = 0.001 # scale factor from CSV power data to FlexPlan power base: here converts from kVA to MVA

    ## Import data

    load_ind    = CSV.read(file_load_ind, DataFrames.DataFrame)
    load_res    = CSV.read(file_load_res, DataFrames.DataFrame)
    profiles_pu = CSV.read(file_profiles_pu, DataFrames.DataFrame; normalizenames=true, limit=number_of_hours)
    if DataFrames.nrow(profiles_pu) < number_of_hours
        Memento.error(_LOGGER, "insufficient number of rows in file \"$file_profiles_pu\" ($number_of_hours requested, $(length(profiles_pu)) found)")
    end
    DataFrames.select!(profiles_pu, :INDUSTRIAL_LOAD => :load_ind, :RESIDENTIAL_LOAD => :load_res, :PV => :pv, :WIND => :wind, :FUEL_CELL => :fuel_cell, :CHP => :chp)
    profiles_pu = Dict(pairs(eachcol(profiles_pu)))

    ## Prepare output structure

    extradata = Dict{String,Any}()
    extradata["dim"] = number_of_hours

    ## Loads

    # Compute active and reactive power base of industrial loads
    DataFrames.rename!(load_ind, [:bus, :s, :cosϕ])
    load_ind.p_ind = scale_load * scale_unit * load_ind.s .* load_ind.cosϕ
    load_ind.q_ind = scale_load * scale_unit * load_ind.s .* sin.(acos.(load_ind.cosϕ))
    DataFrames.select!(load_ind, :bus, :p_ind, :q_ind)

    # Compute active and reactive power base of residential loads
    DataFrames.rename!(load_res, [:bus, :s, :cosϕ])
    load_res.p_res = scale_load * scale_unit * load_res.s .* load_res.cosϕ
    load_res.q_res = scale_load * scale_unit * load_res.s .* sin.(acos.(load_res.cosϕ))
    DataFrames.select!(load_res, :bus, :p_res, :q_res)

    # Create a table of industrial and residential power bases, indexed by the load ids used by `data`
    load_base = coalesce.(DataFrames.outerjoin(load_ind, load_res; on=:bus), 0.0)
    load_base.bus = string.(load_base.bus)
    bus_load_lookup = Dict{String,String}()
    for (l, load) in data["load"]
        bus_load_lookup["$(load["load_bus"])"] = l
    end
    DataFrames.transform!(load_base, :bus => DataFrames.ByRow(b -> bus_load_lookup[b]) => :load_id)

    # Compute active and reactive power profiles of each load
    extradata["load"] = Dict{String,Any}()
    for l in eachrow(load_base)
        extradata["load"][l.load_id] = Dict{String,Any}()
        extradata["load"][l.load_id]["pd"] = l.p_ind .* profiles_pu[:load_ind] .+ l.p_res .* profiles_pu[:load_res]
        extradata["load"][l.load_id]["qd"] = l.q_ind .* profiles_pu[:load_ind] .+ l.q_res .* profiles_pu[:load_res]
    end

    ## Generators

    # Define a Dict for the technology of generators, indexed by the gen ids used by `data`
    gen_tech = Dict{String,Symbol}()
    gen_tech["1"]  = :pv
    gen_tech["2"]  = :pv
    gen_tech["3"]  = :pv
    gen_tech["4"]  = :fuel_cell
    gen_tech["5"]  = :pv
    gen_tech["6"]  = :wind
    gen_tech["7"]  = :pv
    gen_tech["8"]  = :pv
    gen_tech["9"]  = :chp
    gen_tech["10"] = :chp
    gen_tech["11"] = :pv
    gen_tech["12"] = :fuel_cell
    gen_tech["13"] = :pv

    # Compute active and reactive power profiles of each generator
    extradata["gen"]  = Dict{String,Any}()
    for (g, gen) in data["gen"]
        if haskey(gen_tech, g)
            extradata["gen"][g] = Dict{String,Any}()
            extradata["gen"][g]["pmax"] = scale_gen * gen["pmax"] .* profiles_pu[gen_tech[g]]
            extradata["gen"][g]["pmin"] = scale_gen * gen["pmin"] .* profiles_pu[gen_tech[g]]
            extradata["gen"][g]["qmax"] = scale_gen * gen["qmax"] .* ones(number_of_hours)
            extradata["gen"][g]["qmin"] = scale_gen * gen["qmin"] .* ones(number_of_hours)
        end
    end

    return extradata
end

