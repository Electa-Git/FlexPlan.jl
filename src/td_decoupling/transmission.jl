# Attach the surrogate model components to the transmission network bus to which the distribution network is connected
function attach_surrogate_distribution!(t_data::Dict{String,Any}, surr_dist::Dict{String,Any})

    if !haskey(_FP.dim_prop(surr_dist, :sub_nw, 1), "t_bus")
        Memento.error(_LOGGER, "Surrogate model of distribution network does not specify the AC bus to attach to.")
    end
    t_bus = _FP.dim_prop(surr_dist, :sub_nw, 1, "t_bus")

    if _FP.dim_length(surr_dist) ≠ _FP.dim_length(t_data)
        Memento.error(_LOGGER, "Surrogate model to attach to bus $t_bus has $(_FP.dim_length(surr_dist)) networks instead of $(_FP.dim_length(t_data)).")
    end

    surrogate_components = Dict{String,Any}()

    for (n,nw) in t_data["nw"]
        surr_nw = surr_dist["nw"][n]
        comp_id = surrogate_components[n] = Dict{String,String}()

        _FP.convert_mva_base!(surr_nw, nw["baseMVA"])

        g = comp_id["gen"] = string(length(nw["gen"]) + 1)
        gen = surr_nw["gen"]["1"]
        gen["gen_bus"] = t_bus
        nw["gen"][g] = gen

        s = comp_id["storage"] = string(length(nw["storage"]) + 1)
        st = surr_nw["storage"]["1"]
        st["storage_bus"] = t_bus
        nw["storage"][s] = st

        l = comp_id["load"] = string(length(nw["load"]) + 1)
        load = surr_nw["load"]["1"]
        load["load_bus"] = t_bus
        nw["load"][l] = load
    end

    return surrogate_components
end

# Compute the cost of the transmission network, excluding cost related to surrogate model components
function calc_t_objective(t_result::Dict{String,Any}, t_data::Dict{String,Any}, surrogate_components::Vector{Dict{String,Any}})
    nw_raw_cost = Dict{String,Float64}()
    for (n,data_nw) in t_data["nw"]
        nw_raw_cost[n] = 0.0
        sol_nw = t_result["solution"]["nw"][n]
        data_gen = data_nw["gen"]
        sol_gen = sol_nw["gen"]
        data_load = data_nw["load"]
        sol_load = sol_nw["load"]
        for surr_dist in surrogate_components
            g = surr_dist[n]["gen"]
            l = surr_dist[n]["load"]
            nw_raw_cost[n] += (
                data_gen[g]["cost_curt"] * sol_gen[g]["pgcurt"]
                + data_load[l]["cost_curt"] * sol_load[l]["pcurt"]
                + get(data_load[l],"cost_red",0.0) * sol_load[l]["pred"]
                + get(data_load[l],"cost_shift",0.0) * 0.5*(sol_load[l]["pshift_up"]+sol_load[l]["pshift_down"])
            )
        end
    end
    distribution_cost = sum(scenario["probability"] * sum(nw_raw_cost[n] for n in string.(_FP.nw_ids(t_data; scenario=s))) for (s, scenario) in _FP.dim_prop(t_data, :scenario))
    transmission_cost = t_result["objective"] - distribution_cost
    return transmission_cost
end

# Compute the active power exchanged between transmission and distribution, using MVA base of transmission
function calc_exchanged_power(surrogate_components::Dict{String,Any}, t_sol::Dict{String,Any})
    exchanged_power = Dict{String,Float64}()
    for (n, sc) in surrogate_components
        t_nw = t_sol["nw"][n]
        exchanged_power[n] = -t_nw["gen"][sc["gen"]]["pg"] + t_nw["storage"][sc["storage"]]["ps"] + t_nw["load"][sc["load"]]["pflex"]
    end
    return exchanged_power
end

function remove_attached_distribution!(t_sol::Dict{String,Any}, t_data::Dict{String,Any}, surrogate_components::Dict{String,Any})
    for (n,sol_nw) in t_sol["nw"]
        data_nw = t_data["nw"][n]
        comp_id = surrogate_components[n]
        delete!(sol_nw["gen"], comp_id["gen"])
        delete!(data_nw["gen"], comp_id["gen"])
        delete!(sol_nw["storage"], comp_id["storage"])
        delete!(data_nw["storage"], comp_id["storage"])
        delete!(sol_nw["load"], comp_id["load"])
        delete!(data_nw["load"], comp_id["load"])
    end
end
