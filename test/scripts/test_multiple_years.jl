# Test of multinetwork dimensions and multiple planning years


## Import packages and load common code
import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
include("../io/create_profile.jl")
include("../io/multiple_years.jl")
# Solvers are imported later, select name here
solver = "Gurobi"

## Import and set solver
if solver == "Cbc"
    import Cbc
    optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer,
        "logLevel" => 0, # ∈ {0,1}, default: 0
    ) # Solver options: <https://github.com/jump-dev/Cbc.jl#using-with-jump>
elseif solver == "Gurobi"
    import Gurobi
    optimizer = _FP.optimizer_with_attributes(Gurobi.Optimizer) # Solver options: <https://github.com/jump-dev/Cbc.jl#using-with-jump>
end 

## Input parameters

test_case = "case67" # Available test cases (see below): "case6", "case67"
number_of_hours = 10 # Number of hourly optimization periods
number_of_scenarios = 3 # Number of scenarios (different generation/load profiles)
number_of_years = 3
planning_horizon = 10

model_type = _PM.DCPPowerModel
data = create_multi_year_network_data(test_case, number_of_hours, number_of_scenarios, number_of_years, planning_horizon)
result = _FP.stoch_flex_tnep(data, model_type, optimizer; multinetwork=_PM._IM.ismultinetwork(data), setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false))