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
- `year_scale_factor::Int = 10`: how many years a representative year should represent.
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
- `init_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  target dict after its initialization. They must have exactly one argument (the target
  dict) and can modify it; the return value is unused.
- `sn_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  single-network dictionaries containing data for each single year, just before
  `_FP.make_multinetwork` is called. They must have exactly one argument (the single-network
  dict) and can modify it; the return value is unused.
- `share_data::Bool=true`: whether constant data is shared across networks (faster) or
  duplicated (uses more memory, but ensures networks are independent; useful if further
  transformations will be applied).
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
        init_data_extensions::Vector{<:Function} = Function[],
        sn_data_extensions::Vector{<:Function} = Function[],
        share_data::Bool = true,
    )

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

    return create_multi_year_network_data("case6", number_of_hours, number_of_scenarios, number_of_years; year_scale_factor, cost_scale_factor, init_data_extensions, sn_data_extensions, share_data, mc=true)
end

"""
    data, model_type, ref_extensions, solution_processors, setting = load_case6_defaultparams(<keyword arguments>)

Load `case6` in `data` and use default values for the other returned values.

See also: `load_case6`.
"""
function load_case6_defaultparams(; kwargs...)
    load_case6(; kwargs...), load_params_defaults_transmission()...
end

"""
    load_case67(<keyword arguments>)

Load `case67`, a 67-bus transmission network with data contributed by FlexPlan researchers.

# Arguments
- `flex_load::Bool = true`: toggles flexibility of loads.
- `scale_gen::Real = 1.0`: scale factor of all generators.
- `scale_load::Real = 1.0`: scale factor of loads.
- `number_of_hours::Int = 8760`: number of hourly optimization periods.
- `number_of_scenarios::Int = 3`: number of scenarios (different time series for loads and
  RES generators).
- `number_of_years::Int = 3`: number of years (different investment sets).
- `year_scale_factor::Int = 10`: how many years a representative year should represent.
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
- `init_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  target dict after its initialization. They must have exactly one argument (the target
  dict) and can modify it; the return value is unused.
- `sn_data_extensions::Vector{<:Function}=Function[]`: functions to be applied to the
  single-network dictionaries containing data for each single year, just before
  `_FP.make_multinetwork` is called. They must have exactly one argument (the single-network
  dict) and can modify it; the return value is unused.
- `share_data::Bool=true`: whether constant data is shared across networks (faster) or
  duplicated (uses more memory, but ensures networks are independent; useful if further
  transformations will be applied).
"""
function load_case67(;
        flex_load::Bool = true,
        scale_gen::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Int = 8760,
        number_of_scenarios::Int = 3,
        number_of_years::Int = 3,
        year_scale_factor::Int = 10, # years
        cost_scale_factor::Real = 1.0,
        init_data_extensions::Vector{<:Function} = Function[],
        sn_data_extensions::Vector{<:Function} = Function[],
        share_data::Bool = true,
    )

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

    return create_multi_year_network_data("case67", number_of_hours, number_of_scenarios, number_of_years; year_scale_factor, cost_scale_factor, init_data_extensions, sn_data_extensions, share_data)
end

"""
    data, model_type, ref_extensions, solution_processors, setting = load_case67_defaultparams(<keyword arguments>)

Load `case67` in `data` and use default values for the other returned values.

See also: `load_case67`.
"""
function load_case67_defaultparams(; kwargs...)
    load_case67(; kwargs...), load_params_defaults_transmission()...
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
- `share_data::Bool=true`: whether constant data is shared across networks (faster) or
  duplicated (uses more memory, but ensures networks are independent; useful if further
  transformations will be applied).
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
        share_data::Bool = true,
    )

    grid_file = normpath(@__DIR__,"..","data","cigre_mv_eu","cigre_mv_eu_more_storage.m")
    sn_data = _FP.parse_file(grid_file)
    _FP.add_dimension!(sn_data, :hour, number_of_hours)
    _FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)))
    _FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>year_scale_factor))

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
    d_time_series = create_profile_data_cigre(sn_data, number_of_hours; start_period, scale_load, scale_gen, file_profiles_pu=normpath(@__DIR__,"..","data","cigre_mv_eu","time_series","CIGRE_profiles_per_unit_Italy.csv"))
    d_mn_data = _FP.make_multinetwork(sn_data, d_time_series; share_data)

    return d_mn_data
end

"""
    data, model_type, ref_extensions, solution_processors, setting = load_cigre_mv_eu_defaultparams(<keyword arguments>)

Load `cigre_mv_eu` in `data` and use default values for the other returned values.

See also: `load_cigre_mv_eu`.
"""
function load_cigre_mv_eu_defaultparams(; kwargs...)
    load_cigre_mv_eu(; kwargs...), load_params_defaults_distribution()...
end

"""
    load_ieee_33(<keyword arguments>)

Load an extended version of IEEE 33-bus network.

Source: <https://ieeexplore.ieee.org/abstract/document/9258930>

Extensions:
- time series (672 hours, 4 scenarios) for loads and RES generators.

# Arguments
- `oltc::Bool=true`: whether to add an OLTC with ±10% voltage regulation to the transformer.
- `scale_gen::Real = 1.0`: scale factor of all generators.
- `scale_load::Real = 1.0`: scale factor of loads.
- `number_of_hours::Int = 672`: number of hourly optimization periods.
- `number_of_scenarios::Int = 4`: number of scenarios (different time series for loads and
  RES generators).
- `number_of_years::Int = 3`: number of years (different investment sets).
- `energy_cost::Real = 50.0`: cost of energy exchanged with transmission network [€/MWh].
- `cost_scale_factor::Real = 1.0`: scale factor for all costs.
- `share_data::Bool=true`: whether constant data is shared across networks (faster) or
  duplicated (uses more memory, but ensures networks are independent; useful if further
  transformations will be applied).
"""
function load_ieee_33(;
        oltc::Bool = true,
        scale_gen::Real = 1.0,
        scale_load::Real = 1.0,
        number_of_hours::Int = 672,
        number_of_scenarios::Int = 4,
        number_of_years::Int = 3,
        energy_cost::Real = 50.0, # €/MWh
        cost_scale_factor::Real = 1.0,
        share_data::Bool = true,
    )
    file = normpath(@__DIR__,"..","data","ieee_33","ieee_33_672h_4s_3y.json")

    function set_energy_cost!(data)
        data["gen"]["1"]["cost"][end-1] = energy_cost # Coupling generator id is 1 because its String id in the JSON file happens to be the first in alphabetical order.
    end

    return _FP.convert_JSON(
        file;
        oltc,
        scale_gen,
        scale_load,
        number_of_hours,
        number_of_scenarios,
        number_of_years,
        cost_scale_factor,
        sn_data_extensions = [set_energy_cost!],
        share_data,
    )
end

"""
    data, model_type, ref_extensions, solution_processors, setting = load_ieee_33_defaultparams(<keyword arguments>)

Load `ieee_33` in `data` and use default values for the other returned values.

See also: `load_ieee_33`.
"""
function load_ieee_33_defaultparams(; kwargs...)
    load_ieee_33(; kwargs...), load_params_defaults_distribution()...
end


## Auxiliary functions

function load_params_defaults_transmission()
    model_type = _PM.DCPPowerModel
    ref_extensions = Function[_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!]
    solution_processors = Function[_PM.sol_data_model!]
    setting = Dict("output" => Dict("branch_flows"=>true), "conv_losses_mp" => false)
    return model_type, ref_extensions, solution_processors, setting
end

function load_params_defaults_distribution()
    model_type = _FP.BFARadPowerModel
    ref_extensions = Function[_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!]
    solution_processors = Function[_PM.sol_data_model!]
    setting = Dict{String,Any}()
    return model_type, ref_extensions, solution_processors, setting
end

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
