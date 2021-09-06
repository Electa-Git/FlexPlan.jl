# Test of multinetwork dimensions


## Import packages and load common code

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
include("../io/create_profile.jl")
# Solvers are imported later

## Import and set solver

import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer,
    "logLevel" => 0, # ∈ {0,1}, default: 0
) # Solver options: <https://github.com/jump-dev/Cbc.jl#using-with-jump>

## Input parameters

test_case = "case6" # Available test cases (see below): "case6", "cigre"
number_of_hours = 4 # Number of hourly optimization periods
number_of_scenarios = 3 # Number of scenarios (different generation/load profiles)

## Test case preparation

if test_case == "case6" # 6-bus transmission network, max 8760 periods and 35 scenarios

    file = "./test/data/combined_td_model/t_case6.m"
    data = _FP.parse_file(file)

    model_type = _PM.DCPPowerModel
    year_scale_factor = 10

    _FP.add_dimension!(data, :hour, number_of_hours)

    scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
    _FP.add_dimension!(data, :scenario, scenario, metadata = Dict{String,Any}("mc"=>true))

    _FP.scale_data!(data; year_scale_factor)
    data, loadprofile, genprofile = create_profile_data_italy!(data)
    extradata = _FP.create_profile_data(number_of_hours*number_of_scenarios, data, loadprofile, genprofile)
    data = _FP.make_multinetwork(data, extradata)

elseif test_case == "cigre" # 15-bus distribution network, max 24 periods. CIGRE MV test network.

    file = "test/data/combined_td_model/d_cigre.m"
    scale_load = 3.0 # Scaling factor of loads
    scale_gen  = 1.0 # Scaling factor of generators
    data = _FP.parse_file(file)

    model_type = _FP.BFARadPowerModel
    year_scale_factor = 10

    _FP.add_dimension!(data, :hour, number_of_hours)

    number_of_scenarios = 1 # No data available to support multiple scenarios
    scenario = Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios)
    _FP.add_dimension!(data, :scenario, scenario)

    _FP.scale_data!(data; year_scale_factor)
    extradata = create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen)
    data = _FP.make_multinetwork(data, extradata)

end

## Solve problem

result = _FP.stoch_flex_tnep(data, model_type, optimizer; multinetwork=_PM._IM.ismultinetwork(data), setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false))
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"

println("Test completed")