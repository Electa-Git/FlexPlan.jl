function calc_surrogate_model(orig_data::Dict{String,Any}, sol_up::Dict{String,Any}, sol_base::Dict{String,Any}, sol_down::Dict{String,Any}; standalone::Bool=false)
    nws = string.(_FP.nw_ids(orig_data))
    first_nw = first(nws)
    sol_up   = sol_up["nw"]
    sol_base = sol_base["nw"]
    sol_down = sol_down["nw"]

    data = Dict{String,Any}(
        "dim"          => deepcopy(orig_data["dim"]),
        "multinetwork" => true,
        "nw"           => Dict{String,Any}(),
        "per_unit"     => true,
    )
    if standalone
        _FP.dim_prop(data, :sub_nw, 1)["d_gen"] = 2 # Slack generator representing transmission nw.
    end

    template_nw = Dict{String,Any}(
        "baseMVA"      => orig_data["nw"][first_nw]["baseMVA"],
        "time_elapsed" => orig_data["nw"][first_nw]["time_elapsed"],
        "gen"          => Dict{String,Any}(),
        "load"         => Dict{String,Any}(),
        "storage"      => Dict{String,Any}(),
    )
    if standalone
        template_nw["branch"] = Dict{String,Any}(
            "1" => Dict{String,Any}(
                "angmax" => 0.0,
                "angmin" => 0.0,
                "b_fr" => 0.0,
                "b_to" => 0.0,
                "br_r" => 0.0,
                "br_x" => 0.0,
                "br_status" => 1,
                "f_bus" => 1,
                "g_fr" => 0.0,
                "g_to" => 0.0,
                "index" => 1,
                "rate_a" => 0.0,
                "t_bus" => 2,
                "tap" => 1.0,
                "transformer" => false,
            ),
        )
        template_nw["bus"] = Dict{String,Any}(
            "1" => Dict{String,Any}(
                "bus_type" => 3,
                "index" => 1,
                "va" => 0.0,
                "vmax" => 1.0,
                "vmin" => 1.0,
            ),
            "2" => Dict{String,Any}(
                "bus_type" => 1,
                "index" => 2,
                "va" => 0.0,
                "vmax" => 1.0,
                "vmin" => 1.0,
            ),
        )
        template_nw["dcline"] = Dict{String,Any}()
        template_nw["ne_branch"] = Dict{String,Any}()
        template_nw["ne_storage"] = Dict{String,Any}()
        template_nw["shunt"] = Dict{String,Any}()
        template_nw["switch"] = Dict{String,Any}()
    end

    template_gen     = surrogate_gen_const(orig_data["nw"][first_nw]; standalone)
    template_storage = surrogate_storage_const(orig_data["nw"][first_nw], sol_base[first_nw]; standalone)
    template_load    = surrogate_load_const(orig_data["nw"][first_nw], sol_base[first_nw])

    for n in nws
        nw = data["nw"][n] = deepcopy(template_nw)
        nw["storage"]["1"] = surrogate_storage_ts(template_storage, orig_data["nw"][n], sol_up[n], sol_base[n], sol_down[n]; standalone)
        nw["load"]["1"]    = surrogate_load_ts(template_load, nw["storage"]["1"], sol_up[n], sol_base[n], sol_down[n])
        nw["gen"]["1"]     = surrogate_gen_ts(template_gen, nw["load"]["1"], sol_base[n])
        if standalone
            orig_d_gen = _FP.dim_prop(orig_data, :sub_nw, 1, "d_gen")
            nw["gen"]["2"] = deepcopy(orig_data["nw"][n]["gen"]["$orig_d_gen"])
            nw["gen"]["2"]["gen_bus"] = 1
            nw["gen"]["2"]["source_id"] = Vector{String}()
        end
    end

    add_singular_data!(data, orig_data, sol_base)

    return data
end

function surrogate_load_const(od, bs)
    load = Dict{String,Any}(
        "load_bus" => 1,
        "status"   => 1,
    )
    load["cost_curt"] = od["load"]["1"]["cost_curt"] # Assumption: all loads have the same curtailment cost.
    a_flex_load_id = findfirst(l -> l["flex"]>0.5, bs["load"])
    if isnothing(a_flex_load_id)
        load["flex"]       = false
    else
        load["flex"]       = true
        load["cost_red"]   = od["load"][a_flex_load_id]["cost_red"] # Assumption: all flexible loads have the same cost for voluntary reduction.
        load["cost_shift"] = od["load"][a_flex_load_id]["cost_shift"] # Assumption: all flexible loads have the same cost for time shifting.
        load["lifetime"]   = 1
        load["cost_inv"]   = 0.0
    end
    return load
end

function surrogate_gen_const(od; standalone)
    gen = Dict{String,Any}(
        "cost"         => [0.0, 0.0],
        "dispatchable" => false,
        "gen_bus"      => 1,
        "gen_status"   => 1,
        "model"        => 2,
        "ncost"        => 2,
        "pmin"         => 0.0,
    )
    gen["cost_curt"] = od["gen"]["1"]["dispatchable"] ? od["gen"]["2"]["cost_curt"] : od["gen"]["1"]["cost_curt"] # Assumptions: 1. all generators are non-dispatchable (except the generator which simulates the transmission network); 2. all non-dispatchable generators have the same curtailment cost.
    if standalone
        gen["qmax"] = 0.0
        gen["qmin"] = 0.0
    end
    return gen
end

function surrogate_storage_const(od, bs; standalone)
    storage = Dict{String,Any}(
        "self_discharge_rate" => 0.0,
        "status"              => 1,
        "storage_bus"         => 1,
    )
    charge_efficiency = (
        (sum(s["charge_efficiency"]*s["charge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["charge_efficiency"]*s["charge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
        / (sum(s["charge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["charge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
    )
    storage["charge_efficiency"] = isnan(charge_efficiency) ? 0.0 : charge_efficiency
    discharge_efficiency = (
        (sum(s["discharge_efficiency"]*s["discharge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["discharge_efficiency"]*s["discharge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
        / (sum(s["discharge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["discharge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
    )
    storage["discharge_efficiency"] = isnan(discharge_efficiency) ? 0.0 : discharge_efficiency
    storage["energy_rating"] = sum(s["energy_rating"] for s in values(od["storage"]); init=0.0) + sum(s["energy_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0)
    if standalone
        storage["p_loss"] = 0.0
        storage["q_loss"] = 0.0
        storage["qmax"] = 0.0
        storage["qmin"] = 0.0
        storage["r"] = 0.0
        storage["x"] = 0.0
    end
    return storage
end

function surrogate_load_ts(load, storage, up, bs, dn)
    pshift_up_max = min(sum(l["pshift_up"] for l in values(up["load"]); init=0.0)-sum(l["pshift_up"] for l in values(bs["load"]); init=0.0), up["td_coupling"]["p"]-storage["charge_rating"])
    pshift_down_max = sum(l["pshift_down"] for l in values(dn["load"]); init=0.0)-sum(l["pshift_down"] for l in values(bs["load"]); init=0.0)
    pred_max = sum(l["pred"] for l in values(dn["load"]); init=0.0)-sum(l["pred"] for l in values(bs["load"]); init=0.0)
    pd = min(up["td_coupling"]["p"]-storage["charge_rating"]-pshift_up_max, bs["td_coupling"]["p"]-dn["td_coupling"]["p"]-storage["discharge_rating"])

    load = copy(load)
    load["pd"] = pd
    load["pshift_up_rel_max"]   = pshift_up_max / pd
    load["pshift_down_rel_max"] = pshift_down_max / pd
    load["pred_rel_max"]        = pred_max / pd

    return load
end

function surrogate_gen_ts(gen, load, bs)
    gen = copy(gen)
    gen["pmax"] = load["pd"] - bs["td_coupling"]["p"]

    return gen
end

function surrogate_storage_ts(storage, od, up, bs, dn; standalone)
    ps_up = sum(s["ps"] for s in values(get(up,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(up,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ps_bs = sum(s["ps"] for s in values(get(bs,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(bs,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ps_dn = sum(s["ps"] for s in values(get(dn,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(dn,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ext_flow = (
        sum(od["storage"][i]["charge_efficiency"]*s["sc"] - s["sd"]/od["storage"][i]["discharge_efficiency"] for (i,s) in get(bs,"storage",Dict()); init=0.0)
        + sum(od["ne_storage"][i]["charge_efficiency"]*s["sc_ne"] - s["sd_ne"]/od["ne_storage"][i]["discharge_efficiency"] for (i,s) in get(bs,"ne_storage",Dict()) if s["isbuilt"] > 0.5; init=0.0)
    )

    storage = copy(storage)
    storage["charge_rating"]             = min(ps_up - ps_bs, up["td_coupling"]["p"])
    storage["discharge_rating"]          = min(ps_bs - ps_dn, -dn["td_coupling"]["p"])
    storage["stationary_energy_inflow"]  = max.(ext_flow, 0.0)
    storage["stationary_energy_outflow"] = -min.(ext_flow, 0.0)

    if standalone
        storage["thermal_rating"] = 2 * max(storage["charge_rating"], storage["discharge_rating"]) # To avoid that thermal rating limits active power, even in the case of octagonal approximation of apparent power.
    end

    return storage
end

function add_singular_data!(data, orig_data, sol_base)

    # Storage initial energy
    for n in _FP.nw_ids(orig_data; hour=1)
        d = data["nw"]["$n"]
        od = orig_data["nw"]["$n"]
        bs = sol_base["$n"]
        d["storage"]["1"]["energy"] = sum(st["energy"] for st in values(get(od,"storage",Dict())); init=0.0) + sum(od["ne_storage"][s]["energy"] for (s,st) in get(bs,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
    end

    # Storage final energy
    for n in _FP.nw_ids(orig_data; hour=_FP.dim_length(orig_data,:hour))
        d = data["nw"]["$n"]
        od = orig_data["nw"]["$n"]
        bs = sol_base["$n"]
        d["storage"]["1"]["energy"] = sum(st["energy"] for st in values(get(od,"storage",Dict())); init=0.0) + sum(od["ne_storage"][s]["energy"] for (s,st) in get(bs,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
    end
end
