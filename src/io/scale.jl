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
        _PM._apply_func!(load, "cost_shift", rescale) # Compensation for demand shifting
        _PM._apply_func!(load, "cost_curt", rescale)  # Compensation for load curtailment (i.e. involuntary demand reduction)
        _PM._apply_func!(load, "cost_red", rescale)   # Compensation for not consumed energy (i.e. voluntary demand reduction)
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
        _PM._apply_func!(load, "cost_inv", rescale)
        _PM._apply_func!(load, "co2_cost", rescale)
    end
end
