function surrogate_model!(mn_data::Dict{String,Any}; optimizer, setting=Dict{String,Any}())
    flex_profiles = probe_distribution_flexibility!(mn_data; optimizer, setting)
    calc_surrogate_model(mn_data, flex_profiles)
end
