# To add a new cell, type ''
# To add a new markdown cell, type ''

# # Reliability testing in  FlexPlan
using Revise
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels

import JuMP
import Cbc

using JuliaDB
using Plots


# Solver configurations:

cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)


# Input parameters:
number_of_hours = 60 # Number of time points
file = "./test/data/case6_reliability.m";  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage


# Define contingency scenarios for base case (no contingecies):
scenario = Dict{String, Any}("hours" => number_of_hours, "contingency" => Dict{String, Any}())
# Base scenario
scenario["contingency"]["0"] = Dict{String, Any}()
scenario["contingency"]["0"]["year"] = 2019
scenario["contingency"]["0"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["0"]["probability"] = 1.0
scenario["contingency"]["0"]["faults"] = Dict()
scenario["utypes"] = []#, "branchdc_ne"] # type of lines considered in contingencies
scenario["planning_horizon"] = 1 # in years, to scale generation cost  


# # Define and modify input-data
# Load system data from file:
data = _PM.parse_file(file); # Create PowerModels data dictionary (AC networks and storage)


# Create data for the contingency model based on system data and contingency scenarios:
data, contingency_profile, loadprofile, genprofile = _FP.create_contingency_data_italy(data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data


# Translate data profiles into model parameters:
dim = number_of_hours * length(data["contingency"])
extradata = _FP.create_contingency_data(dim, data, contingency_profile, loadprofile, genprofile) # create a dictionary to pass time series 


# # Case system
# Plotting load vs line capacities for AC bus nr. 5:
load_5_scale = 0.85
load_5 = extradata["load"]["5"]["pd"]*load_5_scale
ntime = length(load_5)
pd = reshape(load_5,(ntime,1))
t = collect(1:ntime)
cap_L1 = data["branch"]["1"]["rate_a"]
cap_L2 = data["branch"]["2"]["rate_a"]
cap_L1L2 = cap_L1 + cap_L2

pd_max = maximum(pd)
max_val = maximum([pd_max, cap_L1L2])

line_cap_plot = plot(t, pd, ylim = (0,max_val*1.05), label = "Load bus 5")
plot!([first(t), last(t)], [cap_L1, cap_L1], label = "L1 cap", color = "orange")
plot!([first(t), last(t)], [cap_L2, cap_L2], label = "L2 cap", color = "black")
plot!([first(t), last(t)], [cap_L1L2, cap_L1L2], label = "L1 + L2 cap", color = "red")
display(line_cap_plot)


# We scale the bus 5 load such that lines 1 and 2 can supply the load by themself:
extradata["load"]["5"]["pd"] *= load_5_scale;


# We also have to scale generation in bus 1 to get enough generation through line 1:
gen_1_scale = (1.8/1.4)
extradata["gen"]["1"]["pmax"] *= gen_1_scale;
data["gen"]["1"]["pmax"] *= gen_1_scale;



data["branchdc_ne"]["3"]["cost"] *= 50


# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


#  Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)


# Solve the model for base case:
result_base = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_base, data["contingency"], 5);

savefig(enbal_plot, "energy_balance_base.png")


# Reset and double load from original value:
extradata["load"]["5"]["pd"] *= (2/load_5_scale);
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


# Solve
result_base = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);


# Plot
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_base, data["contingency"], 5);
savefig(enbal_plot, "energy_balance_base_2x_load.png")


# Set load to 10 times original value:
extradata["load"]["5"]["pd"] *= (10/2);
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


# Solve
result_base = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);


# Plot
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_base, data["contingency"], 5);


# **Issue 1: **{style="color:red"} There are no limits on curtailed power (variable: pcurt), such that interrupted power is never used.

# # Load shedding due to contingencies

# After implementing contingency constraints and the objective function term for costs of energy not
# supplied due to contingencies, one could replicate the load shedding tests above where two branches
# feeding load bus 5 are sufficient to supply the load demand but a single branch is not. In the "base case" 
# (intact grid) both branches feeding the load bus should be in an up state, and one of the branches should be 
# included in the contingency list. In this case, load shedding should be represented in the solution by non-zero
# values for the slack variable $\Delta P_{u,c,t,y}$  in the contingency case c=1 and not by any of the other slack variables,
# and there should be no load shedding in the non-contingency case c=0.

scenario = Dict{String, Any}("hours" => number_of_hours, "contingency" => Dict{String, Any}())
# Base scenario
scenario["contingency"]["0"] = Dict{String, Any}()
scenario["contingency"]["0"]["year"] = 2019
scenario["contingency"]["0"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["0"]["probability"] = 0.98
scenario["contingency"]["0"]["faults"] = Dict()
# Contingency 1
scenario["contingency"]["1"] = Dict{String, Any}()
scenario["contingency"]["1"]["year"] = 2019
scenario["contingency"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["1"]["probability"] = 0.01
scenario["contingency"]["1"]["faults"] = Dict("branchdc" => [1])  
# Contingency 2
scenario["contingency"]["2"] = Dict{String, Any}()
scenario["contingency"]["2"]["year"] = 2019
scenario["contingency"]["2"]["start"] = 1546300800000 # 01.01.2019:00:00 in epoch time 
scenario["contingency"]["2"]["probability"] = 0.01
scenario["contingency"]["2"]["faults"] = Dict("branchdc" => [2])
scenario["utypes"] = ["branchdc"] # type of lines considered in contingencies
scenario["planning_horizon"] = 1 # in years, to scale generation cost  



data = _PM.parse_file(file); # Create PowerModels data dictionary (AC networks and storage)
data, contingency_profile, loadprofile, genprofile = _FP.create_contingency_data_italy(data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data
dim = number_of_hours * length(data["contingency"])
extradata = _FP.create_contingency_data(dim, data, contingency_profile, loadprofile, genprofile) # create a dictionary to pass time series


# Scale the load and generation as previously:
extradata["load"]["5"]["pd"] *= load_5_scale;
extradata["gen"]["1"]["pmax"] *= gen_1_scale;
data["gen"]["1"]["pmax"] *= gen_1_scale;
data["branchdc_ne"]["3"]["cost"] *= 100000 # Making building dc line candidate nr. 3 too expensive 


# Create multi-network data:
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


# Solve:
result_2con = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_2con, data["contingency"], 5);
savefig(enbal_plot, "energy_balance_2scen_high_inv_cost.png")


# We get the following investments:
_FP.plot_inv_matrix(result_2con, data["contingency"], "0")
extradata["load"]["5"]["pd"] *= (2/load_5_scale);
data["branchdc_ne"]["3"]["cost"] *= (50/100000) 
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))
result_2con = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_2con, data["contingency"], 5);
savefig(enbal_plot, "energy_balance_2scen_2xload.png")


# Reset investment costs for new dc line nr. 3 to same as base case (10 times costs from input file - not profitable without contingencies): 
extradata["load"]["5"]["pd"] *= (load_5_scale/2);
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))
result_2con = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_2con, data["contingency"], 5);
savefig(enbal_plot, "energy_balance_2scen.png")
_FP.plot_inv_matrix(result_2con, data["contingency"], "0")


# # Sensitivity tests

# Increasing the failure rate or mean time to repair:
#  - Increasing the value of the failure rate of a branch or the mean time to repair for a branch should give changes in the objective value that can be verified analytically.

# Change scenario probability:
scenario["contingency"]["0"]["probability"] = 0.8 # old: 0.98 
scenario["contingency"]["1"]["probability"] = 0.2 # old: 0.01 
scenario["contingency"]["2"]["probability"] = 0.2 # old: 0.01 

# Set new data:
data = _PM.parse_file(file); # Create PowerModels data dictionary (AC networks and storage)
data, contingency_profile, loadprofile, genprofile = _FP.create_contingency_data_italy(data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data
dim = number_of_hours * length(data["contingency"])
extradata = _FP.create_contingency_data(dim, data, contingency_profile, loadprofile, genprofile) # create a dictionary to pass time series
extradata["load"]["5"]["pd"] *= load_5_scale;
extradata["gen"]["1"]["pmax"] *= gen_1_scale;
data["gen"]["1"]["pmax"] *= gen_1_scale;
data["branchdc_ne"]["3"]["cost"] *= 50;
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


# Solve and plot:
result_2con_high_prob = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_2con_high_prob, data["contingency"], 5);
_FP.plot_inv_matrix(result_2con, data["contingency"], "0")
using Printf 
@printf("Objective value low prob: %.2f \n", result_2con["objective"])
@printf("Objective value high prob: %.2f \n", result_2con_high_prob["objective"])
@printf("Relative increase: %.2f percent \n", (result_2con_high_prob["objective"]-result_2con["objective"])*100/result_2con["objective"])

# Combining reliability modelling with flexibility modelling:
# -	It should be possible to straightforwardly combine contingency constraints with flexibility elements e.g. at the load buses 4 or 5. The interactions may be easiest to investigate by first considering a pre-installed flexibility element (i.e. not a candidate). A storage element at the bus at which we are provoking load shedding should reduce the costs of energy not supplied, but it has to be considered more closely how these interactions will play out. Similarly, a demand flexibility at these load buses should give solutions with (voluntary) curtailment of load (and possibly shifting of load) rather than (involuntary) shedding of load. (This requires that the constraints and objective function terms for the flexibility elements are replicated in the model formulation for all contingencies.) There are probably also more subtle interactions that are not anticipated at the test planning stage…

scenario = Dict{String, Any}("hours" => number_of_hours, "contingency" => Dict{String, Any}())
# Base scenario
scenario["contingency"]["0"] = Dict{String, Any}()
scenario["contingency"]["0"]["year"] = 2019
scenario["contingency"]["0"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["0"]["probability"] = 0.97
scenario["contingency"]["0"]["faults"] = Dict()
# Contingency 1
scenario["contingency"]["1"] = Dict{String, Any}()
scenario["contingency"]["1"]["year"] = 2019
scenario["contingency"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["1"]["probability"] = 0.01
scenario["contingency"]["1"]["faults"] = Dict("branchdc" => [1])  
# Contingency 2
scenario["contingency"]["2"] = Dict{String, Any}()
scenario["contingency"]["2"]["year"] = 2019
scenario["contingency"]["2"]["start"] = 1546300800000 # 01.01.2019:00:00 in epoch time 
scenario["contingency"]["2"]["probability"] = 0.01
scenario["contingency"]["2"]["faults"] = Dict("branchdc" => [2])
# Contingency 3
scenario["contingency"]["3"] = Dict{String, Any}()
scenario["contingency"]["3"]["year"] = 2019
scenario["contingency"]["3"]["start"] = 1546300800000 # 01.01.2019:00:00 in epoch time 
scenario["contingency"]["3"]["probability"] = 0.01
scenario["contingency"]["3"]["faults"] = Dict("branchdc_ne" => [3])
scenario["utypes"] = ["branchdc", "branchdc_ne"] # type of lines considered in contingencies
scenario["planning_horizon"] = 1 # in years, to scale generation cost

data = _PM.parse_file(file); # Create PowerModels data dictionary (AC networks and storage)
data, contingency_profile, loadprofile, genprofile = _FP.create_contingency_data_italy(data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data
dim = number_of_hours * length(data["contingency"])
extradata = _FP.create_contingency_data(dim, data, contingency_profile, loadprofile, genprofile) # create a dictionary to pass time series
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))


extradata["load"]["5"]["pd"] *= load_5_scale;
extradata["gen"]["1"]["pmax"] *= gen_1_scale;
data["gen"]["1"]["pmax"] *= gen_1_scale;
data["branchdc_ne"]["3"]["cost"] *= 10 



result_3con = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s);
enbal_plot = _FP.plot_energy_balance_scenarios(mn_data, result_3con, data["contingency"], 5);
savefig(enbal_plot, "energy_balance_3scen.png")






