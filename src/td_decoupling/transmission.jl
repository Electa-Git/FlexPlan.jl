# Attach the surrogate model components to the transmission network bus to which the distribution network is connected
function attach_surrogate_distribution!(t_data::Dict{String,Any}, surr_dist::Dict{String,Any})

    if _FP.dim_length(surr_dist) ≠ _FP.dim_length(t_data)
        Memento.error(_LOGGER, "Surrogate model to attach to bus $t_bus has $(_FP.dim_length(surr_dist)) networks instead of $(_FP.dim_length(t_data))")
    end

    t_bus = _FP.dim_prop(surr_dist, :sub_nw, 1, "t_bus")

    for (n,nw) in t_data["nw"]
        surr_nw = surr_dist["nw"][n]

        _FP.convert_mva_base!(surr_nw, nw["baseMVA"])

        g = length(nw["gen"]) + 1
        gen = surr_nw["gen"]["1"]
        gen["gen_bus"] = t_bus
        nw["gen"]["$g"] = gen

        s = length(nw["storage"]) + 1
        st = surr_nw["storage"]["1"]
        st["storage_bus"] = t_bus
        nw["storage"]["$s"] = st

        l = length(nw["load"]) + 1
        load = surr_nw["load"]["1"]
        load["load_bus"] = t_bus
        nw["load"]["$l"] = load
    end
end
