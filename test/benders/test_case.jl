# Function to load test cases used in Benders decomposition testing

include("../io/create_profile.jl")
include("../io/multiple_years.jl")

function load_test_case(test_case_name::String; number_of_hours::Int, number_of_scenarios::Int, number_of_years::Int, scale_cost)
    if test_case_name in ["case6", "case67"]
        # `case6`:   6-bus transmission network. Max 8760 hours, 35 scenarios, 3 years.
        # `case67`: 67-bus transmission network. Max 8760 hours,  3 scenarios, 3 years.

        model_type = _PM.DCPPowerModel
        data = create_multi_year_network_data(test_case_name, number_of_hours, number_of_scenarios, number_of_years; cost_scale_factor = scale_cost)

    elseif test_case_name in ["cigre", "cigre_ext"]
        # `cigre`:     15-bus distribution network. Max   24 hours, 1 scenario, 1 year.
        # `cigre_ext`: 15-bus distribution network. Max 8760 hours, 1 scenario, 1 year.

        scale_load = 3.0 # Scale factor of loads
        scale_gen  = 1.0 # Scale factor of generators
        model_type = _FP.BFARadPowerModel
        file = "test/data/combined_td_model/d_cigre.m"
        file_profiles_pu = test_case_name == "cigre" ? "./test/data/CIGRE_profiles_per_unit.csv" : "./test/data/CIGRE_profiles_per_unit_Italy.csv"
        data = _FP.parse_file(file)
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios))
        _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>10))
        _FP.scale_data!(data; cost_scale_factor = scale_cost) # Add `year_idx` parameter when using on multi-year instances
        time_series = create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen, file_profiles_pu)
        data = _FP.make_multinetwork(data, time_series)

    elseif test_case_name == "case2"
        # `case2`: 2-bus distribution network. Max 1 hour, 1 scenario, 1 year.

        model_type = _FP.BFARadPowerModel
        file = "./test/data/case2.m"
        data = _FP.parse_file(file)
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios))
        _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>10))
        _FP.scale_data!(data; cost_scale_factor = scale_cost)
        data = _FP.make_multinetwork(data)

    else
        Memento.error(_LOGGER, "Test case \"$test_case_name\" not implemented.")

    end

    ref_extensions = (model_type == _PM.DCPPowerModel
        ? Function[_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!]
        : Function[_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!]
    )
    solution_processors = Function[_PM.sol_data_model!]
    setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

    return data, model_type, ref_extensions, solution_processors, setting
end
