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

function add_flexible_demand_data!(data)
    for (le, load_extra) in data["load_extra"]

        # ID of load point
        idx = load_extra["load_id"]

        # Superior bound on not consumed power (voluntary load reduction) as a fraction of the total reference demand (0 ≤ p_shift_up_max ≤ 1)
        data["load"]["$idx"]["p_red_max"] = load_extra["p_red_max"]

        # Superior bound on upward demand shifted as a fraction of the total reference demand (0 ≤ p_shift_up_max ≤ 1)
        data["load"]["$idx"]["p_shift_up_max"] = load_extra["p_shift_up_max"]

        # Superior bound on downward demand shifted as a fraction of the total reference demand (0 ≤ p_shift_down_max ≤ 1)
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

        # Superior bound on energy not consumed as a fraction of the total reference demand (0 ≤ e_nce_max ≤ 1)
        data["load"]["$idx"]["e_nce_max"] = load_extra["e_nce_max"]

        # Expected lifetime of flexibility-enabling equipment (years)
        data["load"]["$idx"]["lifetime"] = load_extra["lifetime"]

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

"""
    scale_data!(data; <keyword arguments>)

Scale lifetime and cost data.

See `_scale_time_data!`, `_scale_operational_cost_data!` and `_scale_investment_cost_data!`.

# Arguments
- `data`: a single-network data dictionary.
- `number_of_hours`: number of optimization periods (default: `dim_length(data, :hour)`).
- `year_scale_factor`: how many years a representative year should represent (default: `dim_meta(data, :year, "scale_factor")`).
- `number_of_years`: number of representative years (default: `dim_length(data, :year)`).
- `year_idx`: id of the representative year (default: `1`).
- `cost_scale_factor`: scale factor for all costs (default: `1.0`).
"""
function scale_data!(
        data::Dict{String,Any};
        number_of_hours::Int = haskey(data, "dim") ? dim_length(data, :hour) : 1,
        year_scale_factor::Int = haskey(data, "dim") ? dim_meta(data, :year, "scale_factor") : 1,
        number_of_years::Int = haskey(data, "dim") ? dim_length(data, :year) : 1,
        year_idx::Int = 1,
        cost_scale_factor::Float64 = 1.0
    )
    if _IM.ismultinetwork(data)
        Memento.error(_LOGGER, "`scale_data!` can only be applied to single-network data dictionaries.")
    end
    _scale_time_data!(data, year_scale_factor)
    _scale_operational_cost_data!(data, number_of_hours, year_scale_factor, cost_scale_factor)
    _scale_investment_cost_data!(data, number_of_years, year_idx, cost_scale_factor) # Must be called after `_scale_time_data!`
end

"""
    _scale_time_data!(data, year_scale_factor)

Scale lifetime data from years to periods of `year_scale_factor` years.

After applying this function, the step between consecutive years takes the value 1: in this
way it is easier to write the constraints that link variables belonging to different years.
"""
function _scale_time_data!(data, year_scale_factor)
    rescale = x -> x ÷ year_scale_factor
    for component in ("ne_branch", "branchdc_ne", "ne_storage", "convdc_ne", "load")
        for (key, val) in get(data, component, Dict{String,Any}())
            if !haskey(val, "lifetime")
                if component == "load" && !Bool(get(val, "flex", 0))
                    continue # "lifetime" field might not be used in cases where the load is not flexible
                else
                    Memento.error(_LOGGER, "Missing `lifetime` key in `$component` $key.")
                end
            end
            if val["lifetime"] % year_scale_factor != 0
                Memento.error(_LOGGER, "Lifetime of $component $key ($(val["lifetime"])) must be a multiple of the year scale factor ($year_scale_factor).")
            end
            _PM._apply_func!(val, "lifetime", rescale)
        end
    end
end

"""
    _scale_operational_cost_data!(data, number_of_hours, year_scale_factor, cost_scale_factor)

Scale hourly costs to the planning horizon.

Scale hourly costs so that the sum of the costs over all optimization periods
(`number_of_hours` hours) represents the cost over the entire planning horizon
(`year_scale_factor` years). In this way it is possible to perform the optimization using a
reduced number of hours and still obtain a cost that approximates the cost that would be
obtained if 8760 hours were used for each year.
"""
function _scale_operational_cost_data!(data, number_of_hours, year_scale_factor, cost_scale_factor)
    rescale = x -> (8760*year_scale_factor / number_of_hours) * cost_scale_factor * x # scale hourly costs to the planning horizon
    for (g, gen) in data["gen"]
        _PM._apply_func!(gen, "cost", rescale)
    end
    for (l, load) in data["load"]
        _PM._apply_func!(load, "cost_shift_up", rescale)     # Compensation for demand shifting
        _PM._apply_func!(load, "cost_shift_down", rescale)   # Compensation for demand shifting
        _PM._apply_func!(load, "cost_curtailment", rescale)  # Compensation for load curtailment (i.e. involuntary demand reduction)
        _PM._apply_func!(load, "cost_reduction", rescale)    # Compensation for consuming less (i.e. voluntary demand reduction)
    end
    _PM._apply_func!(data, "co2_emission_cost", rescale)
end

"""
    _scale_investment_cost_data!(data, number_of_years, year_idx, cost_scale_factor)

Correct investment costs considering the residual value at the end of the planning horizon.

Linear depreciation is assumed.

This function _must_ be called after `_scale_time_data!`.
"""
function _scale_investment_cost_data!(data, number_of_years, year_idx, cost_scale_factor)
    # Assumption: the `lifetime` parameter of investment candidates has already been scaled
    # using `_scale_time_data!`.
    remaining_years = number_of_years - year_idx + 1
    for (b, branch) in get(data, "ne_branch", Dict{String,Any}())
        rescale = x -> min(remaining_years/branch["lifetime"], 1.0) * cost_scale_factor * x
        _PM._apply_func!(branch, "construction_cost", rescale)
        _PM._apply_func!(branch, "co2_cost", rescale)
    end
    for (b, branch) in get(data, "branchdc_ne", Dict{String,Any}())
        rescale = x -> min(remaining_years/branch["lifetime"], 1.0) * cost_scale_factor * x
        _PM._apply_func!(branch, "cost", rescale)
        _PM._apply_func!(branch, "co2_cost", rescale)
    end
    for (c, conv) in get(data, "convdc_ne", Dict{String,Any}())
        rescale = x -> min(remaining_years/conv["lifetime"], 1.0) * cost_scale_factor * x
        _PM._apply_func!(conv, "cost", rescale)
        _PM._apply_func!(conv, "co2_cost", rescale)
    end
    for (s, strg) in get(data, "ne_storage", Dict{String,Any}())
        rescale = x -> min(remaining_years/strg["lifetime"], 1.0) * cost_scale_factor * x
        _PM._apply_func!(strg, "eq_cost", rescale)
        _PM._apply_func!(strg, "inst_cost", rescale)
        _PM._apply_func!(strg, "co2_cost", rescale)
    end
    for (l, load) in data["load"]
        rescale = x -> min(remaining_years/load["lifetime"], 1.0) * cost_scale_factor * x
        _PM._apply_func!(load, "cost_investment", rescale)
        _PM._apply_func!(load, "co2_cost", rescale)
    end
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
