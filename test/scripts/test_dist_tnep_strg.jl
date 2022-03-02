# Test of the distribution network model when used in multi-period network expansion planning
# considering storage investments


## Import packages and choose a solver

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)

include("../io/create_profile.jl")

## Input parameters

data_file       = "test/data/CIGRE_MV_benchmark_network_strg.m" # Input case: here CIGRE distribution network with non-dispatchable generators, storage and candidate storage
number_of_hours = 24   # Number of hourly optimization periods. Used profiles allow up to 8760 periods.
scale_load      =  1.0 # Scaling factor of loads
scale_gen       =  4.9 # Scaling factor of generators (increase to get an infeasible problem, decrease to avoid ne_storage)


## Load and preprocess data

# Create FlexPlan single-network data dictionary
data = _FP.parse_file(data_file; flex_load=false)

# Generate hourly time profiles for loads and generators, based on CIGRE benchmark distribution network.
time_series = create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen)

# Create multi-period data dictionary where time series data is included at the right place
_FP.add_dimension!(data, :hour, number_of_hours)
_FP.add_dimension!(data, :year, 1)
mn_data = _FP.make_multinetwork(data, time_series)


## Solve problem

# PowerModels and FlexPlan settings
s = Dict("output" => Dict("branch_flows" => true))

result = _FP.strg_tnep(mn_data, _FP.BFARadPowerModel, optimizer; setting=s)
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Write results

# Text summary of the first period of the optimal solution
#_PM.print_summary(result["solution"]["nw"]["1"])
