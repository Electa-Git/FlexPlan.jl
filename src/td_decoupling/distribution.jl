function apply_td_coupling_power_active_with_zero_cost!(d_data::Dict{String,Any}, t_data::Dict{String,Any}, exchanged_power::Dict{String,Float64})
    for (n, d_nw) in d_data["nw"]
        t_nw = t_data["nw"][n]

        # Compute the active power exchanged between transmission and distribution in MVA base of distribution
        p = exchanged_power[n] * (t_nw["baseMVA"]/d_nw["baseMVA"])

        # Fix distribution generator power to the computed value
        d_gen_id = _FP.dim_prop(d_data, parse(Int,n), :sub_nw, "d_gen")
        d_gen = d_nw["gen"]["$d_gen_id"] = deepcopy(d_nw["gen"]["$d_gen_id"]) # Gen data is shared among nws originally.
        d_gen["pmax"] = p
        d_gen["pmin"] = p

        # Set distribution generator cost to zero
        d_gen["model"] = 2 # Cost model (2 => polynomial cost)
        d_gen["ncost"] = 0 # Number of cost coefficients
        d_gen["cost"]  = Any[]
    end
end
