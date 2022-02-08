"""
    parse_file(file; flex_load=true, <keyword arguments>)

Parse a Matpower .m `file` or PTI (PSS(R)E-v33) .raw `file` into a FlexPlan data structure,
including DC components, storage and flexible loads.

`flex_load` specifies whether to process flexible load data.
Other keyword arguments, if any, are forwarded to `PowerModels.parse_file()`.

Mandatory tables: `bus`, `gen`, `branch` (and `load_extra` if `flex_load==true`).
Optional tables: `gencost`, `branch_oltc`, `storage`, `storage_extra`, `ne_storage`.
Other tables can be added as well: they will be made available in the returned object.
"""
function parse_file(file::String; flex_load=true, kwargs...)
    data = _PM.parse_file(file; kwargs...)
    if !haskey(data, "ne_branch")
        data["ne_branch"] = Dict{String,Any}()
    end
    if haskey(data, "busdc") || haskey(data, "busdc_ne")
        _PMACDC.process_additional_data!(data)
    end
    add_storage_data!(data)
    if flex_load
        if !haskey(data, "load_extra")
            Memento.error(_LOGGER, "No `load_extra` table found in input file.")
        end
        add_flexible_demand_data!(data)
    end
    return data
end

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

        # Superior bound on voluntary load reduction (not consumed power) as a fraction of the total reference demand (0 ≤ pred_rel_max ≤ 1)
        data["load"]["$idx"]["pred_rel_max"] = load_extra["pred_rel_max"]

        # Superior bound on upward demand shifted as a fraction of the total reference demand (0 ≤ pshift_up_rel_max ≤ 1)
        data["load"]["$idx"]["pshift_up_rel_max"] = load_extra["pshift_up_rel_max"]

        # Superior bound on downward demand shifted as a fraction of the total reference demand (0 ≤ pshift_down_rel_max ≤ 1)
        data["load"]["$idx"]["pshift_down_rel_max"] = load_extra["pshift_down_rel_max"]

        # Superior bound on shifted energy as a fraction of the total reference demand (0 ≤ eshift_rel_max ≤ 1)
        if haskey(load_extra, "eshift_rel_max")
            data["load"]["$idx"]["eshift_rel_max"] = load_extra["eshift_rel_max"]
        end

        # Compensation for consuming less (i.e. voluntary demand reduction) (€/MWh)
        data["load"]["$idx"]["cost_red"] = load_extra["cost_red"]

        # Recovery period for upward demand shifting (h)
        if haskey(load_extra, "tshift_up")
            data["load"]["$idx"]["tshift_up"] = load_extra["tshift_up"]
        end

        # Recovery period for downward demand shifting (h)
        if haskey(load_extra, "tshift_down")
            data["load"]["$idx"]["tshift_down"] = load_extra["tshift_down"]
        end

        # Compensation for demand shifting (€/MWh), applied only to the power shifted upward to avoid double counting
        data["load"]["$idx"]["cost_shift"] = load_extra["cost_shift"]

        # Compensation for load curtailment (i.e. involuntary demand reduction) (€/MWh)
        data["load"]["$idx"]["cost_curt"] = load_extra["cost_curt"]

        # Investment costs for enabling flexible demand (€)
        data["load"]["$idx"]["cost_inv"] = load_extra["cost_inv"]

        # Whether load is flexible (boolean)
        data["load"]["$idx"]["flex"] = load_extra["flex"]

        # Superior bound on voluntary energy reduction as a fraction of the total reference demand (0 ≤ ered_rel_max ≤ 1)
        if haskey(load_extra, "ered_rel_max")
            data["load"]["$idx"]["ered_rel_max"] = load_extra["ered_rel_max"]
        end

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
        _PM._apply_func!(data["load"]["$idx"], "cost_red", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_shift", rescale_cost)
        _PM._apply_func!(data["load"]["$idx"], "cost_curt", rescale_cost)
        if haskey(load_extra, "cost_voll")
            _PM._apply_func!(data["load"]["$idx"], "cost_voll", rescale_cost)
        end
    end
    delete!(data, "load_extra")
    return data
end

function add_generation_emission_data!(data)
    rescale_emission = x -> x * data["baseMVA"]
    for (g, gen) in data["gen"]
        _PM._apply_func!(gen, "emission_factor", rescale_emission)
    end
    return data
end
