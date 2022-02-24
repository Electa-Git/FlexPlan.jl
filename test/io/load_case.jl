# Functions to load complete test cases from files hosted in the repository

include("create_profile.jl")

"""
    load_cigre_mv_eu(<keyword arguments>)

Load an extended version of CIGRE MV benchmark network (EU configuration).

Source: <https://e-cigre.org/publication/ELT_273_8-benchmark-systems-for-network-integration-of-renewable-and-distributed-energy-resources>, chapter 6.2

Extensions:
- storage at bus 14 (in addition to storage at buses 5 and 10, altready present);
- candidate storage at buses 5, 10, and 14;
- time series (8760 hours) for loads and RES generators.

# Arguments
- `flex_load::Bool = false`: toggles flexibility of loads.
- `ne_storage::Bool = false`: toggles candidate storage.
- `scale_gen::Float64 = 1.0`: scaling factor of all generators, wind included.
- `scale_wind::Float64 = 1.0`: further scaling factor of wind generator.
- `scale_load::Float64 = 1.0`: scaling factor of loads.
- `energy_cost::Float64 = 50.0`: cost of energy exchanged with transmission network [€/MWh].
- `year_scale_factor::Int = 10`: how many years a representative year should represent [years].
- `number_of_hours::Int = 8760`: number of hourly optimization periods.
- `start_period::Int = 1`: first period of time series to use.
"""
function load_cigre_mv_eu(;
        flex_load::Bool = false,
        ne_storage::Bool = false,
        scale_gen::Float64 = 1.0,
        scale_wind::Float64 = 1.0,
        scale_load::Float64 = 1.0,
        energy_cost::Float64 = 50.0, # €/MWh
        year_scale_factor::Int = 10, # years
        number_of_hours::Int = 8760,
        start_period::Int = 1,
    )

    grid_file = "test/data/combined_td_model/d_cigre_more_storage.m"
    sn_data = _FP.parse_file(grid_file)
    _FP.add_dimension!(sn_data, :hour, number_of_hours)
    _FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)), metadata = Dict{String,Any}("mc"=>true))
    _FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
    _FP.add_dimension!(sn_data, :sub_nw, 1)

    # Set cost of energy exchanged with transmission network
    sn_data["gen"]["14"]["ncost"] = 2
    sn_data["gen"]["14"]["cost"] = [energy_cost, 0.0]

    # Scale wind generation
    sn_data["gen"]["6"]["pmin"] *= scale_wind
    sn_data["gen"]["6"]["pmax"] *= scale_wind
    sn_data["gen"]["6"]["qmin"] *= scale_wind
    sn_data["gen"]["6"]["qmax"] *= scale_wind

    # Toggle flexible demand
    for load in values(sn_data["load"])
        load["flex"] = flex_load ? 1 : 0
    end

    # Toggle candidate storage
    if !ne_storage
        sn_data["ne_storage"] = Dict{String,Any}()
    end

    _FP.scale_data!(sn_data)
    _FP.add_td_coupling_data!(sn_data; sub_nw = 1)
    d_time_series = create_profile_data_cigre(sn_data, number_of_hours; start_period, scale_load, scale_gen, file_profiles_pu="test/data/CIGRE_profiles_per_unit_Italy.csv")
    d_mn_data = _FP.make_multinetwork(sn_data, d_time_series)

    return d_mn_data
end