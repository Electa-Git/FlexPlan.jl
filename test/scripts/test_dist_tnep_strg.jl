# Test of the distribution network model when used in multi-period network expansion planning
# considering storage investments


## Import packages and choose a solver

import PowerModels
const _PM = PowerModels
import PowerModelsACDC
const _PMACDC = PowerModelsACDC
import FlexPlan
const _FP = FlexPlan
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Input parameters

data_file       = "test/data/CIGRE_MV_benchmark_network_strg.m" # Input case: here CIGRE distribution network with non-dispatchable generators, storage and candidate storage
number_of_hours = 24    # Number of hourly optimization periods. Used profiles allow up to 8760 periods.
scale_load      =  1.0  # Scaling factor of loads
scale_gen       =  2.45 # Scaling factor of generators (increase to get an infeasible problem, decrease to avoid ne_storage)


## Load and preprocess data

# Create PowerModels data dictionary (AC networks and storage)
data = _PM.parse_file(data_file)

# Handle missing fields of the MATPOWER case file
data["ne_branch"] = Dict{String,Any}()

# Generate hourly time profiles for loads and generators (base values from CIGRE distribution network, profiles from Italy data).
extradata = _FP.create_profile_data_cigre_italy(data, number_of_hours; scale_load = scale_load, scale_gen = scale_gen)

# Add storage data to the data dictionary
_FP.add_storage_data!(data)

# Create multi-period data dictionary where time series data is included at the right place
mn_data = _FP.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))


## Solve problem

# PowerModels and FlexPlan settings
s = Dict("output" => Dict("branch_flows" => true))

result = _FP.strg_tnep(mn_data, _FP.BFARadPowerModel, optimizer; multinetwork=true, setting=s)
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Write results

# Text summary of the first period of the optimal solution
#_PM.print_summary(result["solution"]["nw"]["1"])
