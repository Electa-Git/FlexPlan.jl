# Functions to load complete test cases from files hosted in the repository

include("create_profile.jl")
include("multiple_years.jl")

"""
    load_case6(<keyword arguments>)

Load `case6`, a 6-bus transmission network with data contributed by FlexPlan researchers.

# Arguments
- `flex_load::Bool = true`: toggles flexibility of loads.
- `scale_gen::Real = 1.0`: scale factor of all generators.
- `scale_load::Real = 1.0`: scale factor of loads.
- `number_of_hours::Int = 8760`: number of hourly optimization periods.
- `number_of_scenarios::Int = 35`: number of scenarios (different time series for loads and
  RES generators).
- `number_of_years::Int = 3`: number of years (different investment sets).
- `year_scale_factor::Int = 10`: how many years a representative year should represent [years].
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
"""
function load_case6(;
        flex_load::Bool = true,
        scale_gen::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Int = 8760,
        number_of_scenarios::Int = 35,
        number_of_years::Int = 3,
        year_scale_factor::Int = 10, # years
        cost_scale_factor::Real = 1.0,
    )

    sn_data_extensions = Function[]
    if !flex_load
        function fixed_load!(data)
            for load in values(data["load"])
                load["flex"] = 0
            end
        end
        push!(sn_data_extensions, fixed_load!)
    end
    if scale_gen ≠ 1.0
        push!(sn_data_extensions, data_scale_gen(scale_gen))
    end
    if scale_load ≠ 1.0
        push!(sn_data_extensions, data_scale_load(scale_load))
    end

    return create_multi_year_network_data("case6", number_of_hours, number_of_scenarios, number_of_years; year_scale_factor, cost_scale_factor, sn_data_extensions, mc=true)
end

"""
    load_cigre_mv_eu(<keyword arguments>)

Load an extended version of CIGRE MV benchmark network (EU configuration).

Source: <https://e-cigre.org/publication/ELT_273_8-benchmark-systems-for-network-integration-of-renewable-and-distributed-energy-resources>, chapter 6.2

Extensions:
- storage at bus 14 (in addition to storage at buses 5 and 10, already present);
- candidate storage at buses 5, 10, and 14;
- time series (8760 hours) for loads and RES generators.

# Arguments
- `flex_load::Bool = false`: toggles flexibility of loads.
- `ne_storage::Bool = false`: toggles candidate storage.
- `scale_gen::Real = 1.0`: scale factor of all generators, wind included.
- `scale_wind::Real = 1.0`: further scaling factor of wind generator.
- `scale_load::Real = 1.0`: scale factor of loads.
- `number_of_hours::Int = 8760`: number of hourly optimization periods.
- `start_period::Int = 1`: first period of time series to use.
- `year_scale_factor::Int = 10`: how many years a representative year should represent [years].
- `energy_cost::Real = 50.0`: cost of energy exchanged with transmission network [€/MWh].
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
"""
function load_cigre_mv_eu(;
        flex_load::Bool = false,
        ne_storage::Bool = false,
        scale_gen::Real = 1.0,
        scale_wind::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Int = 8760,
        start_period::Int = 1,
        year_scale_factor::Int = 10, # years
        energy_cost::Real = 50.0, # €/MWh
        cost_scale_factor::Real = 1.0,
    )

    grid_file = normpath(@__DIR__,"..","data","cigre_mv_eu","cigre_mv_eu_more_storage.m")
    sn_data = _FP.parse_file(grid_file)
    _FP.add_dimension!(sn_data, :hour, number_of_hours)
    _FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)))
    _FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))
    _FP.add_dimension!(sn_data, :sub_nw, 1)

    # Set cost of energy exchanged with transmission network
    sn_data["gen"]["1"]["ncost"] = 2
    sn_data["gen"]["1"]["cost"] = [energy_cost, 0.0]

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

    _FP.scale_data!(sn_data; cost_scale_factor)
    _FP.add_td_coupling_data!(sn_data; sub_nw = 1)
    d_time_series = create_profile_data_cigre(sn_data, number_of_hours; start_period, scale_load, scale_gen, file_profiles_pu=normpath(@__DIR__,"..","data","cigre_mv_eu","time_series","CIGRE_profiles_per_unit_Italy.csv"))
    d_mn_data = _FP.make_multinetwork(sn_data, d_time_series)

    return d_mn_data
end

"""
    load_ieee_33(<keyword arguments>)

Load an extended version of IEEE 33-bus network.

Source: <https://ieeexplore.ieee.org/abstract/document/9258930>

Extensions:
- time series (672 hours, 4 scenarios) for loads and RES generators.

# Arguments
- `scale_gen::Real = 1.0`: scale factor of all generators.
- `scale_load::Real = 1.0`: scale factor of loads.
- `number_of_hours::Int = 672`: number of hourly optimization periods.
- `number_of_scenarios::Int = 4`: number of scenarios (different time series for loads and
  RES generators).
- `number_of_years::Int = 3`: number of years (different investment sets).
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
"""
function load_ieee_33(;
        scale_gen::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Int = 672,
        number_of_scenarios::Int = 4,
        number_of_years::Int = 3,
        cost_scale_factor::Real = 1.0,
    )
    file = normpath(@__DIR__,"..","data","ieee_33","ieee_33_672h_4s_3y.json")

    return _FP.convert_JSON(
        file;
        scale_gen,
        scale_load,
        number_of_hours,
        number_of_scenarios,
        number_of_years,
        cost_scale_factor,
        init_data_extensions = [data -> _FP.add_dimension!(data, :sub_nw, 1)],
        sn_data_extensions = [sn_data -> _FP.add_td_coupling_data!(sn_data; sub_nw=1)],
    )
end


## Auxiliary functions

function data_scale_gen(gen_scale_factor)
    return data -> (
        for gen in values(data["gen"])
            gen["pmax"] *= gen_scale_factor
            gen["pmin"] *= gen_scale_factor
            if haskey(gen, "qmax")
                gen["qmax"] *= gen_scale_factor
                gen["qmin"] *= gen_scale_factor
            end
        end
    )
end

function data_scale_load(load_scale_factor)
    return data -> (
        for load in values(data["load"])
            load["pd"] *= load_scale_factor
            if haskey(load, "qd")
                load["qd"] *= load_scale_factor
            end
        end
    )
end
