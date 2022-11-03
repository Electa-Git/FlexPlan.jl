# Test of multinetwork dimensions and multiple planning years


## Import packages and load common code
import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
include("../io/create_profile.jl")
include("../io/multiple_years.jl")


## Import and set solver
import HiGHS
optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
#import CPLEX
#optimizer = _FP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput"=>0)


## Input parameters

test_case = "case6" # Available test cases: "case6", "case67"
number_of_hours = 4 # Number of hourly optimization periods
number_of_scenarios = 2 # Number of scenarios (different generation/load profiles)
number_of_years = 3 # Number of years (different investments)
cost_scale_factor = 1.0 # Scale factor for all costs
model_type = _PM.DCPPowerModel


## Generate test case

data = create_multi_year_network_data(test_case, number_of_hours, number_of_scenarios, number_of_years; cost_scale_factor)


## Solve problem

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "add_co2_cost" => false)

# One-step alternative, does not expose pm
#result = _FP.stoch_flex_tnep(data, model_type, optimizer, multinetwork=_FP._IM.ismultinetwork(data); setting=s)

# Two-step alternative, exposes pm
pm = _PM.instantiate_model(data, model_type, _FP.build_stoch_flex_tnep; ref_extensions=[_FP.ref_add_gen!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting=s)
result = _PM.optimize_model!(pm; optimizer)

@assert result["termination_status"] ∈ (_FP.OPTIMAL, _FP.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"

println("Test completed")
