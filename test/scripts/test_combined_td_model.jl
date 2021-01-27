# Test of the transmission and distribution combined model


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

# Number of hourly optimization periods
number_of_hours = 3 # TODO: reset to 24

# PowerModels, PowerModelsACDC and FlexPlan settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)


## Transmission network instance (all data preparation except for multinetwork_data() call)

t_file = "./test/data/case6_realistic_costs.m" # Input case for transmission network
scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
scenario["sc_years"]["1"] = Dict{String, Any}()
scenario["sc_years"]["1"]["year"] = 2019
scenario["sc_years"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time  
scenario["sc_years"]["1"]["probability"] = 1   # 01.01.2019:00:00 in epoch time
scenario["planning_horizon"] = 1 # in years, to scale generation cost  

t_data = _PM.parse_file(t_file) # Create PowerModels data dictionary (AC networks and storage)
t_data, t_loadprofile, t_genprofile = _FP.create_profile_data_italy(t_data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(t_data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(t_data) # Add addtional storage data model
_FP.add_flexible_demand_data!(t_data) # Add flexible data model
_FP.scale_cost_data!(t_data, scenario) # Scale cost data
dim = number_of_hours * length(t_data["scenario"])
t_extradata = _FP.create_profile_data(dim, t_data, t_loadprofile, t_genprofile) # create a dictionary to pass time series data to data dictionary


## Distribution network instance (all data preparation except for multinetwork_data() call)

d_file      = "test/data/CIGRE_MV_benchmark_network_flex.m" # Input case for distribution networks
d_load_file = "./test/data/CIGRE_MV_benchmark_network_flex_load_extra.csv" # Flexible load data for distribution networks
scale_load  = 1.0  # Scaling factor of loads
scale_gen   = 2.45 # Scaling factor of generators (increase to get an infeasible problem, decrease to avoid ne_storage)

# Create PowerModels data dictionary (AC networks and storage)
d_data = _PM.parse_file(d_file)
# Handle missing fields of the MATPOWER case file
d_data["ne_branch"] = Dict{String,Any}()
# Generate hourly time profiles for loads and generators (base values from CIGRE distribution network, profiles from Italy data).
d_extradata = _FP.create_profile_data_cigre_italy(d_data, number_of_hours; scale_load, scale_gen)
# Add storage data to the data dictionary
_FP.add_storage_data!(d_data)
# Add extra_load array for demand flexibility model parameters
d_data = _FP.read_case_data_from_csv(d_data,d_load_file,"load_extra")
# Add flexible data model
_FP.add_flexible_demand_data!(d_data)


## T&D coupling and multinetwork data preparation

_FP.add_td_coupling_data!(t_data, d_data; t_bus = 1)
t_mn_data = _FP.multinetwork_data(t_data, t_extradata, Set{String}(["source_type","scenario","name","source_version","per_unit"]))
d_mn_data = _FP.multinetwork_data(d_data, d_extradata, Set{String}(["source_type","scenario","name","source_version","per_unit"]); nw_id_offset=t_extradata["dim"])


## Solve problem

result = _FP.flex_tnep(t_mn_data, d_mn_data, _PM.DCPPowerModel, _FP.BFARadPowerModel, optimizer; setting=s)
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
