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

    template_gen     = surrogate_gen_const(; standalone)
    template_storage = surrogate_storage_const(orig_data["nw"][first_nw], sol_base[first_nw]; standalone)
    template_load    = surrogate_load_const(sol_base[first_nw])

    for n in nws
        nw = data["nw"][n] = deepcopy(template_nw)
        nw["storage"]["1"] = surrogate_storage_ts(template_storage, orig_data["nw"][n], sol_up[n], sol_base[n], sol_down[n]; standalone)
        nw["load"]["1"]    = surrogate_load_ts(template_load, orig_data["nw"][n], nw["storage"]["1"], sol_up[n], sol_base[n], sol_down[n])
        nw["gen"]["1"]     = surrogate_gen_ts(template_gen, orig_data["nw"][n], nw["load"]["1"], sol_base[n])
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

function surrogate_load_const(bs)
    load = Dict{String,Any}(
        "load_bus" => 1,
        "status"   => 1,
    )
    if any(ld -> ld.second["flex"]>0.5, bs["load"])
        load["flex"]     = true
        load["lifetime"] = 1
        load["cost_inv"] = 0.0
    else
        load["flex"] = false
    end
    return load
end

function surrogate_gen_const(; standalone)
    gen = Dict{String,Any}(
        "cost"         => [0.0, 0.0],
        "dispatchable" => false,
        "gen_bus"      => 1,
        "gen_status"   => 1,
        "model"        => 2,
        "ncost"        => 2,
        "pmin"         => 0.0,
    )
    if standalone
        gen["qmax"] = 0.0
        gen["qmin"] = 0.0
    end
    return gen
end

function surrogate_storage_const(od, bs; standalone)
    storage = Dict{String,Any}(
        "status"               => 1,
        "storage_bus"          => 1,
        "energy_rating"        => sum(s["energy_rating"] for s in values(od["storage"]); init=0.0) + sum(s["energy_rating"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0),
        "self_discharge_rate"  => min(minimum(s["self_discharge_rate"] for s in values(od["storage"]); init=1.0), minimum(s["self_discharge_rate"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=1.0)),
        "charge_efficiency"    => max(maximum(s["charge_efficiency"] for s in values(od["storage"]); init=0.0), maximum(s["charge_efficiency"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.0)),
        # When the distribution network does not have storage devices, surrogate model's
        # storage energy rating is 0, so it can not be used in practice and the other
        # parameters should not be relevant.
        # However, a 0.0 discharge efficiency would cause Inf coefficients in energy
        # constraints, which in turn would cause errors when instantiating the model.
        # Therefore, it is better to initialize the discharge efficiency using a small
        # positive value, such as 0.001.
        "discharge_efficiency" => max(maximum(s["discharge_efficiency"] for s in values(od["storage"]); init=0.0), maximum(s["discharge_efficiency"] for (i,s) in od["ne_storage"] if bs["ne_storage"][i]["isbuilt"] > 0.5; init=0.001)),
    )
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

function surrogate_load_ts(load, od, storage, up, bs, dn)
    pshift_up_max = min(sum(l["pshift_up"] for l in values(up["load"]); init=0.0)-sum(l["pshift_up"] for l in values(bs["load"]); init=0.0), up["td_coupling"]["p"]-storage["charge_rating"])
    pshift_down_max = sum(l["pshift_down"] for l in values(dn["load"]); init=0.0)-sum(l["pshift_down"] for l in values(bs["load"]); init=0.0)
    pred_max = sum(l["pred"] for l in values(dn["load"]); init=0.0)-sum(l["pred"] for l in values(bs["load"]); init=0.0)
    pd = min(up["td_coupling"]["p"]-storage["charge_rating"]-pshift_up_max, bs["td_coupling"]["p"]-dn["td_coupling"]["p"]-storage["discharge_rating"])

    load = copy(load)
    load["pd"]                  = max(pd, 0.0)
    load["pshift_up_rel_max"]   = pd>0 ? pshift_up_max/pd : 0.0
    load["pshift_down_rel_max"] = pd>0 ? pshift_down_max/pd : 0.0
    load["pred_rel_max"]        = pd>0 ? pred_max/pd : 0.0
    load["cost_curt"]           = minimum(ld["cost_curt"] for ld in values(od["load"]))
    if load["flex"]
        load["cost_red"]        = minimum(od["load"][l]["cost_red"] for (l,ld) in bs["load"] if ld["flex"]>0.5)
        load["cost_shift"]      = minimum(od["load"][l]["cost_shift"] for (l,ld) in bs["load"] if ld["flex"]>0.5)
    end

    return load
end

function surrogate_gen_ts(gen, od, load, bs)
    gen = copy(gen)
    gen["pmax"] = load["pd"] - bs["td_coupling"]["p"]
    # Assumption: all generators are non-dispatchable (except the generator that simulates the transmission network, which has already been removed from the solution dict).
    gen["cost_curt"] = isempty(bs["gen"]) ? 0.0 : minimum(od["gen"][g]["cost_curt"] for (g,gen) in bs["gen"])
    return gen
end

function surrogate_storage_ts(storage, od, up, bs, dn; standalone)
    ps_up = sum(s["ps"] for s in values(get(up,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(up,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ps_bs = sum(s["ps"] for s in values(get(bs,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(bs,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ps_dn = sum(s["ps"] for s in values(get(dn,"storage",Dict())); init=0.0) + sum(s["ps_ne"] for s in values(get(dn,"ne_storage",Dict())) if s["isbuilt"] > 0.5; init=0.0)
    ext_flow = (
        sum(
                od["storage"][i]["charge_efficiency"]*s["sc"]
                - s["sd"]/od["storage"][i]["discharge_efficiency"]
                + od["storage"][i]["stationary_energy_inflow"]
                - od["storage"][i]["stationary_energy_outflow"]
            for (i,s) in get(bs,"storage",Dict());
            init=0.0
        )
        + sum(
                od["ne_storage"][i]["charge_efficiency"]*s["sc_ne"]
                - s["sd_ne"]/od["ne_storage"][i]["discharge_efficiency"]
                + od["ne_storage"][i]["stationary_energy_inflow"]
                - od["ne_storage"][i]["stationary_energy_outflow"]
            for (i,s) in get(bs,"ne_storage",Dict()) if s["isbuilt"] > 0.5;
            init=0.0
        )
    )

    storage = copy(storage)
    storage["charge_rating"]             = min(ps_up - ps_bs, up["td_coupling"]["p"])
    storage["discharge_rating"]          = min(ps_bs - ps_dn, -dn["td_coupling"]["p"])
    storage["stationary_energy_inflow"]  = max.(ext_flow, 0.0)
    storage["stationary_energy_outflow"] = -min.(ext_flow, 0.0)
    storage["thermal_rating"]            = 2 * max(storage["charge_rating"], storage["discharge_rating"]) # To avoid that thermal rating limits active power, even in the case of octagonal approximation of apparent power.
    storage["p_loss"]                    = 0.0
    storage["q_loss"]                    = 0.0
    storage["r"]                         = 0.0
    storage["x"]                         = 0.0

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
