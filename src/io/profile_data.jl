function add_storage_data!(data)
    if haskey(data, "storage")
        for (s, storage) in data["storage"]
            rescale_power = x -> x/data["baseMVA"]
            _PM._apply_func!(storage, "max_energy_absorption", rescale_power)
            _PM._apply_func!(storage, "stationary_energy_outflow", rescale_power)
            _PM._apply_func!(storage, "stationary_energy_inflow", rescale_power)
        end
    else
        data["storage"] = Dict{String,Any}()
    end

    if haskey(data, "ne_storage")
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
    else
        data["ne_storage"] = Dict{String,Any}()
    end

    return data
end

function scale_cost_data!(data, planning_horizon)
    hours = length(data["dim"][:hour])
    rescale_hourly = x -> (8760*planning_horizon / hours) * x # scale hourly costs to the planning horizon
    rescale_total  = x -> (                    1 / hours) * x # scale total costs to the planning horizon
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
        _PM._apply_func!(load, "cost_shift_up", rescale_hourly)     # Compensation for demand shifting
        _PM._apply_func!(load, "cost_shift_down", rescale_hourly)   # Compensation for demand shifting
        _PM._apply_func!(load, "cost_curtailment", rescale_hourly)  # Compensation for load curtailment (i.e. involuntary demand reduction)
        _PM._apply_func!(load, "cost_reduction", rescale_hourly)    # Compensation for consuming less (i.e. voluntary demand reduction)
        _PM._apply_func!(load, "cost_investment", rescale_total)    # Investment costs for enabling flexible demand
        _PM._apply_func!(load, "co2_cost", rescale_total)           # CO2 costs for enabling flexible demand
    end
    _PM._apply_func!(data, "co2_emission_cost", rescale_hourly)
end

function add_flexible_demand_data!(data)
    for (le, load_extra) in data["load_extra"]

        # ID of load point
        idx = load_extra["load_id"]

        # Superior bound on not consumed power (voluntary load reduction) (p.u., 0 \leq p_shift_up_max \leq 1)
        data["load"]["$idx"]["p_red_max"] = load_extra["p_red_max"]

        # Superior bound on upward demand shifted (p.u., 0 \leq p_shift_up_max \leq 1)
        data["load"]["$idx"]["p_shift_up_max"] = load_extra["p_shift_up_max"]

        # Superior bound on downward demand shifted (p.u., 0 \leq p_shift_up_max \leq 1)
        data["load"]["$idx"]["p_shift_down_max"] = load_extra["p_shift_down_max"]

        # Maximum energy (accumulated load) shifted downward during time horizon (MWh)
        data["load"]["$idx"]["p_shift_down_tot_max"] = load_extra["p_shift_down_tot_max"]

        # Compensation for consuming less (i.e. voluntary demand reduction) (€/MWh)
        data["load"]["$idx"]["cost_reduction"] = load_extra["cost_reduction"]

        # Recovery period for upward demand shifting (h)
        data["load"]["$idx"]["t_grace_up"] = load_extra["t_grace_up"]

        # Recovery period for downward demand shifting (h)
        data["load"]["$idx"]["t_grace_down"] = load_extra["t_grace_down"]

        # Compensation for downward demand shifting (€/MWh)
        data["load"]["$idx"]["cost_shift_down"] = load_extra["cost_shift_down"]

        # Compensation for upward demand shifting (€/MWh); usually, the c_shift_up parameter should be set to zero
        # to avoid double-counting of the flexibility activation cost, since demand shifted downwards at some point
        # needs to be shifted upwards again
        data["load"]["$idx"]["cost_shift_up"] = load_extra["cost_shift_up"]

        # Compensation for load curtailment (i.e. involuntary demand reduction) (€/MWh)
        data["load"]["$idx"]["cost_curtailment"] = load_extra["cost_curt"]

        # Investment costs for enabling flexible demand (€)
        data["load"]["$idx"]["cost_investment"] = load_extra["cost_inv"]

        # Whether load is flexible (boolean)
        data["load"]["$idx"]["flex"] = load_extra["flex"]

        # Maximum energy not consumed (accumulated voluntary load reduction) (MWh)
        data["load"]["$idx"]["e_nce_max"] = load_extra["e_nce_max"]

        # Value of Lost Load (VOLL), i.e. costs for load curtailment due to contingencies (€/MWh)
        if haskey(load_extra, "cost_voll")
            data["load"]["$idx"]["cost_voll"] = load_extra["cost_voll"]
        end

        # CO2 costs for enabling flexible demand (€)
        if haskey(load_extra, "co2_cost")
            data["load"]["$idx"]["co2_cost"] = load_extra["co2_cost"]
        end

        # Power factor angle θ, giving the reactive power as Q = P ⨉ tan(θ)
        if haskey(load_extra, "pf_angle")
            data["load"]["$idx"]["pf_angle"] = load_extra["pf_angle"]
        end

        # Rescale cost and power input values to the p.u. values used internally in the model
        rescale_cost = x -> x*data["baseMVA"]
        rescale_power = x -> x/data["baseMVA"]
        _PM._apply_func!(data["load"]["$idx"], "cost_reduction", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_up", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift_down", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_curtailment", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "e_nce_max", rescale_power)
        if haskey(load_extra, "cost_voll")
            _PM._apply_func!(data["load"]["$idx"], "cost_voll", rescale_cost)
        end
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

function create_profile_data(number_of_periods, data, loadprofile = ones(length(data["load"]), number_of_periods), genprofile = ones(length(data["gen"]), number_of_periods))
    extradata = Dict{String,Any}()
    extradata["load"] = Dict{String,Any}()
    extradata["gen"] = Dict{String,Any}()
    for (l, load) in data["load"]
        extradata["load"][l] = Dict{String,Any}()
        extradata["load"][l]["pd"] = Array{Float64,2}(undef, 1, number_of_periods)
        for d in 1:number_of_periods
            extradata["load"][l]["pd"][1, d] = data["load"][l]["pd"] * loadprofile[parse(Int, l), d]
        end
    end

    for (g, gen) in data["gen"]
        extradata["gen"][g] = Dict{String,Any}()
        extradata["gen"][g]["pmax"] = Array{Float64,2}(undef, 1, number_of_periods)
        for d in 1:number_of_periods
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

