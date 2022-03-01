function calc_surrogate_model(orig_data::Dict{String,Any}, flex_profiles::Dict{String,Any})
    nws = flex_profiles["ids"]["nw"]
    first_nw = first(nws)
    r_up   = flex_profiles["result"]["up"]["solution"]["nw"]
    r_base = flex_profiles["result"]["base"]["solution"]["nw"]
    r_down = flex_profiles["result"]["down"]["solution"]["nw"]

    data = Dict{String,Any}(
        "dim"          => deepcopy(orig_data["dim"]),
        "multinetwork" => true,
        "nw"           => Dict{String,Any}(),
        "per_unit"     => true,
    )

    template_nw = Dict{String,Any}(
        "baseMVA"      => orig_data["nw"][first_nw]["baseMVA"],
        "time_elapsed" => orig_data["nw"][first_nw]["time_elapsed"],
        "gen"          => Dict{String,Any}(),
        "load"         => Dict{String,Any}(),
        "storage"      => Dict{String,Any}(),
    )

    template_gen     = surrogate_gen_const(orig_data["nw"][first_nw])
    template_storage = surrogate_storage_const(orig_data["nw"][first_nw], r_base[first_nw])
    template_load    = surrogate_load_const(orig_data["nw"][first_nw], r_base[first_nw])

    for n in nws
        nw = data["nw"][n] = copy(template_nw)
        nw["storage"]["1"] = surrogate_storage_ts(template_storage, orig_data["nw"][n], r_up[n], r_base[n], r_down[n])
        nw["load"]["1"]    = surrogate_load_ts(template_load, nw["storage"]["1"], r_up[n], r_base[n], r_down[n])
        nw["gen"]["1"]     = surrogate_gen_ts(template_gen, nw["load"]["1"], r_base[n])
    end

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
    end
    return load
end

function surrogate_gen_const(od)
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
    return gen
end

function surrogate_storage_const(od, bs)
    storage = Dict{String,Any}(
        "self_discharge_rate" => 0.0,
        "status"              => 1,
        "storage_bus"         => 1,
    )
    storage["charge_efficiency"] = (
        (sum(s["charge_efficiency"]*s["charge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["charge_efficiency"]*s["charge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
        / (sum(s["charge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["charge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
    )
    storage["discharge_efficiency"] = (
        (sum(s["discharge_efficiency"]*s["discharge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["discharge_efficiency"]*s["discharge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
        / (sum(s["discharge_rating"] for s in values(od["storage"]); init=0.0) + sum(s["discharge_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0))
    )
    storage["energy_rating"] = sum(s["energy_rating"] for s in values(od["storage"]); init=0.0) + sum(s["energy_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0)
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

    return gen, load
end

function surrogate_storage_ts(storage, od, up, bs, dn)
    ps_up = sum(s["ps"] for s in values(up["storage"]); init=0.0) + sum(s["ps_ne"] for s in values(up["ne_storage"]) if s["isbuilt"] > 0.5; init=0.0)
    ps_bs = sum(s["ps"] for s in values(bs["storage"]); init=0.0) + sum(s["ps_ne"] for s in values(bs["ne_storage"]) if s["isbuilt"] > 0.5; init=0.0)
    ps_dn = sum(s["ps"] for s in values(dn["storage"]); init=0.0) + sum(s["ps_ne"] for s in values(dn["ne_storage"]) if s["isbuilt"] > 0.5; init=0.0)
    ext_flow = (
        sum(od["storage"][i]["charge_rating"]*s["sc"]+od["storage"][i]["discharge_rating"]*s["sd"] for (i,s) in bs["storage"]; init=0.0)
        + sum(od["storage"][i]["charge_rating"]*s["sc_ne"]+od["storage"][i]["discharge_rating"]*s["sd_ne"] for (i,s) in bs["ne_storage"] if s["isbuilt"] > 0.5; init=0.0)
    )

    storage = copy(storage)
    storage["charge_rating"]             = min(ps_up - ps_bs, up["td_coupling"]["p"])
    storage["discharge_rating"]          = min(ps_bs - ps_dn, -dn["td_coupling"]["p"])
    storage["stationary_energy_inflow"]  = max.(ext_flow, 0.0)
    storage["stationary_energy_outflow"] = -min.(ext_flow, 0.0)

    return storage
end
