function surrogate_model!(mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}())
    sol_up, sol_base, sol_down = probe_distribution_flexibility!(mn_data; optimizer, setting)
    calc_surrogate_model(mn_data, sol_up, sol_base, sol_down)
end
