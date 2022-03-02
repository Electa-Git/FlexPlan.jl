import CSV
import DataFrames
import JSON

# Kept for compatibility with legacy code.
function create_profile_data(number_of_periods, data, loadprofile = ones(length(data["load"]),number_of_periods), genprofile = ones(length(data["gen"]),number_of_periods))
    _FP.make_time_series(data, number_of_periods; loadprofile = permutedims(loadprofile), genprofile = permutedims(genprofile))
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

function create_profile_data_italy!(data)

    hours = _FP.dim_length(data, :hour)
    scenarios = _FP.dim_length(data, :scenario)

    genprofile = ones(length(data["gen"]), hours*scenarios)
    loadprofile = ones(length(data["load"]), hours*scenarios)

    monte_carlo = get(_FP.dim_meta(data, :scenario), "mc", false)

    for (s, scnr) in _FP.dim_prop(data, :scenario)
        pv_sicily, pv_south_central, wind_sicily = read_res_data(s; mc = monte_carlo)
        demand_center_north_pu, demand_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu = read_demand_data(s; mc = monte_carlo)

        start_idx = (s-1) * hours
        if monte_carlo == false
            for h in 1 : hours
                h_idx = scnr["start"] + ((h-1) * 3600000)
                genprofile[3, start_idx + h] = pv_south_central["data"]["$h_idx"]["electricity"]
                genprofile[5, start_idx + h] = pv_sicily["data"]["$h_idx"]["electricity"]
                genprofile[6, start_idx + h] = wind_sicily["data"]["$h_idx"]["electricity"]
            end
        else
            genprofile[3, start_idx + 1 : start_idx + hours] = pv_south_central[1: hours]
            genprofile[5, start_idx + 1 : start_idx + hours] = pv_sicily[1: hours]
            genprofile[6, start_idx + 1 : start_idx + hours] = wind_sicily[1: hours]
        end
        loadprofile[:, start_idx + 1 : start_idx + hours] = [demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1: hours]
        # loadprofile[:, start_idx + 1 : start_idx + number_of_hours] = repeat([demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1],1,number_of_hours)
    end
    # Add bus locations to data dictionary
    data["bus"]["1"]["lat"] = 43.4894; data["bus"]["1"]["lon"] = 11.7946; # Italy central north
    data["bus"]["2"]["lat"] = 45.3411; data["bus"]["2"]["lon"] =  9.9489; # Italy north
    data["bus"]["3"]["lat"] = 41.8218; data["bus"]["3"]["lon"] = 13.8302; # Italy central south
    data["bus"]["4"]["lat"] = 40.5228; data["bus"]["4"]["lon"] = 16.2155; # Italy south
    data["bus"]["5"]["lat"] = 40.1717; data["bus"]["5"]["lon"] =  9.0738; # Sardinia
    data["bus"]["6"]["lat"] = 37.4844; data["bus"]["6"]["lon"] = 14.1568; # Sicily
    # Return info
    return data, loadprofile, genprofile
end

function create_profile_data_germany!(data)

    hours = _FP.dim_length(data, :hour)
    scenarios = _FP.dim_length(data, :scenario)

    genprofile = ones(length(data["gen"]), hours*scenarios)
    loadprofile = ones(length(data["load"]), hours*scenarios)

    monte_carlo = get(_FP.dim_meta(data, :scenario), "mc", false)

    for (s, scnr) in _FP.dim_prop(data, :scenario)
        wind_profile = read_res_data(s; mc = monte_carlo, country = "de")
        demand_profile = read_demand_data(s; mc = monte_carlo, country = "de")
        start_idx = (s-1) * hours
        if monte_carlo == false
            for h in 1 : hours
                h_idx = scnr["start"] + ((h-1) * 3600000)
                genprofile[2, start_idx + h] = wind_profile["2"]["data"]["$h_idx"]["electricity"]
                genprofile[4, start_idx + h] = wind_profile["5"]["data"]["$h_idx"]["electricity"]
                genprofile[20, start_idx + h] = wind_profile["67"]["data"]["$h_idx"]["electricity"]
                if length(data["gen"]) > 20
                    genprofile[21, start_idx + h] = wind_profile["23"]["data"]["$h_idx"]["electricity"]
                elseif length(data["gen"]) > 21
                    genprofile[22, start_idx + h] = wind_profile["54"]["data"]["$h_idx"]["electricity"]
                end
            end
        end
        loadprofile[:, start_idx + 1 : start_idx + hours] .= repeat(demand_profile[1:hours]', size(loadprofile, 1))
    end
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

    path_demand_data = normpath(@__DIR__,"..","..","test","data","demand_Norway_2015.csv")
    demand_data = CSV.read(path_demand_data, DataFrames.DataFrame)
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

"Create load and generation profiles for CIGRE distribution network."
function create_profile_data_cigre(data, number_of_hours; start_period = 1, scale_load = 1.0, scale_gen = 1.0, file_profiles_pu = "./test/data/CIGRE_profiles_per_unit.csv")

    ## Fixed parameters

    file_load_ind    = "./test/data/CIGRE_industrial_loads.csv"
    file_load_res    = "./test/data/CIGRE_residential_loads.csv"
    scale_unit       = 0.001 # scale factor from CSV power data to FlexPlan power base: here converts from kVA to MVA

    ## Import data

    load_ind    = CSV.read(file_load_ind, DataFrames.DataFrame)
    load_res    = CSV.read(file_load_res, DataFrames.DataFrame)
    profiles_pu = CSV.read(
        file_profiles_pu,
        DataFrames.DataFrame;
        skipto = start_period + 1, # +1 is for header line
        limit = number_of_hours,
        ntasks = 1 # To ensure exact row limit is applied
    )
    if DataFrames.nrow(profiles_pu) < number_of_hours
        Memento.error(_LOGGER, "insufficient number of rows in file \"$file_profiles_pu\" ($number_of_hours requested, $(DataFrames.nrow(profiles_pu)) found)")
    end
    DataFrames.select!(profiles_pu,
        :industrial_load  => :load_ind,
        :residential_load => :load_res,
        :photovoltaic     => :pv,
        :wind_turbine     => :wind,
        :fuel_cell        => :fuel_cell,
        :CHP_diesel       => :chp_diesel,
        :CHP_fuel_cell    => :chp_fuel_cell
    )
    profiles_pu = Dict(pairs(eachcol(profiles_pu)))

    ## Prepare output structure

    extradata = Dict{String,Any}()

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
    gen_tech["9"]  = :chp_diesel
    gen_tech["10"] = :chp_fuel_cell
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

function read_demand_data(year; mc = false, country = "it")
    if country == "it"
        if mc == false
            if year > 2
                error("Only 2 scenarios are supported")
            end
            y = year + 2017
            # Read demand CSV files
            demand_north = CSV.read(normpath(@__DIR__,"../../test/data/demand_north_$y.csv"),DataFrames.DataFrame)[:,3]
            demand_center_north = CSV.read(normpath(@__DIR__,"../../test/data/demand_center_north_$y.csv"),DataFrames.DataFrame)[:,3]
            demand_center_south = CSV.read(normpath(@__DIR__,"../../test/data/demand_center_south_$y.csv"),DataFrames.DataFrame)[:,3]
            demand_south = CSV.read(normpath(@__DIR__,"../../test/data/demand_south_$y.csv"),DataFrames.DataFrame)[:,3]
            demand_sardinia = CSV.read(normpath(@__DIR__,"../../test/data/demand_sardinia_$y.csv"),DataFrames.DataFrame)[:,3]

            # Convert demand_profile to pu of maxximum
            demand_north_pu = demand_north ./ maximum(demand_north)
            demand_center_north_pu = demand_center_north ./ maximum(demand_center_north)
            demand_south_pu = demand_south ./ maximum(demand_south)
            demand_center_south_pu = demand_center_south ./ maximum(demand_center_south)
            demand_sardinia_pu = demand_sardinia ./ maximum(demand_sardinia)
        else
            if year > 35
                error("Only 35 scenarios are supported")
            end
            y = year - 1
            demand_north_pu = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_demand_$y.csv"),DataFrames.DataFrame)[:,3]
            demand_center_north_pu = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_demand_$y.csv"),DataFrames.DataFrame)[:,2]
            demand_center_south_pu = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_demand_$y.csv"),DataFrames.DataFrame)[:,4]
            demand_south_pu = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_demand_$y.csv"),DataFrames.DataFrame)[:,5]
            demand_sardinia_pu = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_demand_$y.csv"),DataFrames.DataFrame)[:,6]
        end

        return demand_north_pu, demand_center_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu
    elseif country == "de"
        if year > 3
            error("Only 3 scenarios are supported")
        end
        y = year + 2016
        demand = CSV.read(normpath(@__DIR__,"../../test/data/multiple_years/case67/demand$y.csv"),DataFrames.DataFrame)[:,3]
        demand_pu = demand ./ maximum(demand)
        return demand_pu[1:4:end]
    end
end

function read_res_data(year; mc = false, country = "it")
    if country == "it"
        if mc == false
            if year > 2
                error("Only 2 scenarios are supported")
            end
            y = year + 2017
            pv_sicily = Dict()
            open(normpath(@__DIR__,"../../test/data/pv_sicily_$y.json")) do f
                dicttxt = read(f, String)  # file information to string
                pv_sicily = JSON.parse(dicttxt)  # parse and transform data
            end

            pv_south_central = Dict()
            open(normpath(@__DIR__,"../../test/data/pv_south_central_$y.json")) do f
                dicttxt = read(f, String)  # file information to string
                pv_south_central = JSON.parse(dicttxt)  # parse and transform data
            end

            wind_sicily = Dict()
            open(normpath(@__DIR__,"../../test/data/wind_sicily_$y.json")) do f
                dicttxt = read(f, String)  # file information to string
                wind_sicily = JSON.parse(dicttxt)  # parse and transform data
            end
        else
            if year > 35
                error("Only 35 scenarios are supported")
            end
            y = year - 1
            pv_sicily = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_PV_$y.csv"),DataFrames.DataFrame)[:,7]
            pv_south_central = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_PV_$y.csv"),DataFrames.DataFrame)[:,4]
            wind_sicily = CSV.read(normpath(@__DIR__,"../../test/data/MC_scenarios/35_yearly_clusters/case_6_wind_$y.csv"),DataFrames.DataFrame)[:,7]
        end
        return pv_sicily, pv_south_central, wind_sicily
    elseif country == "de"
        if year > 3
            error("Only 3 scenarios are supported")
        end
        y = year + 2016
        wind_profile = Dict{String, Any}()
        open(normpath(@__DIR__,"../../test/data/multiple_years/case67/wind_bus2_$y.json")) do f
            dicttxt = read(f, String)  # file information to string
            wind_profile["2"] = JSON.parse(dicttxt)  # parse and transform data
        end
        open(normpath(@__DIR__,"../../test/data/multiple_years/case67/wind_bus5_$y.json")) do f
            dicttxt = read(f, String)  # file information to string
            wind_profile["5"]  = JSON.parse(dicttxt)  # parse and transform data
        end
        open(normpath(@__DIR__,"../../test/data/multiple_years/case67/wind_bus23_$y.json")) do f
            dicttxt = read(f, String)  # file information to string
            wind_profile["23"]  = JSON.parse(dicttxt)  # parse and transform data
        end
        open(normpath(@__DIR__,"../../test/data/multiple_years/case67/wind_bus54_$y.json")) do f
            dicttxt = read(f, String)  # file information to string
            wind_profile["54"]  = JSON.parse(dicttxt)  # parse and transform data
        end
        open(normpath(@__DIR__,"../../test/data/multiple_years/case67/wind_bus67_$y.json")) do f
            dicttxt = read(f, String)  # file information to string
            wind_profile["67"]  = JSON.parse(dicttxt)  # parse and transform data
        end
        return wind_profile
    end
end
