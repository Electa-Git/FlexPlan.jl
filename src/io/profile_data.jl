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

function create_profile_data(dim, data, loadprofile)
    genprofile = ones(1, dim)
    extradata = Dict{String,Any}()
    extradata["dim"] = Dict{String,Any}()
    extradata["dim"] = dim
    extradata["load"] = Dict{String,Any}()
    extradata["gen"] = Dict{String,Any}()
    for (l, load) in data["load"]
        extradata["load"][l] = Dict{String,Any}()
        extradata["load"][l]["pd"] = Array{Float64,2}(undef, 1, dim)
        for d in 1:dim
            extradata["load"][l]["pd"][1, d] = data["load"][l]["pd"] * loadprofile[parse(Int, l), d]
        end
    end

    for (g, gen) in data["gen"]
        extradata["gen"][g] = Dict{String,Any}()
        extradata["gen"][g]["pmax"] = Array{Float64,2}(undef, 1, dim)
        for d in 1:dim
            extradata["gen"][g]["pmax"][1, d] = data["gen"][g]["pmax"] * genprofile[d]
        end
    end

    return extradata
end
