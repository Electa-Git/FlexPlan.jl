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
number_of_hours = 24

# PowerModels, PowerModelsACDC and FlexPlan settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)


## Transmission network instance (all data preparation except for multinetwork_data() call)

t_file = "./test/data/combined_td_model/t_case6.m" # Input case for transmission network
scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
scenario["sc_years"]["1"] = Dict{String, Any}()
scenario["sc_years"]["1"]["year"] = 2019
scenario["sc_years"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time  
scenario["sc_years"]["1"]["probability"] = 1   # 01.01.2019:00:00 in epoch time
scenario["planning_horizon"] = 1 # in years, to scale generation cost  

t_data = _PM.parse_file(t_file)
t_data, t_loadprofile, t_genprofile = _FP.create_profile_data_italy(t_data, scenario) # Create load and generation profiles
_PMACDC.process_additional_data!(t_data)
_FP.add_storage_data!(t_data)
_FP.add_flexible_demand_data!(t_data)
_FP.scale_cost_data!(t_data, scenario)
t_extradata = _FP.create_profile_data(scenario["hours"]*length(t_data["scenario"]), t_data, t_loadprofile, t_genprofile) # Create a dictionary to pass time series data to data dictionary


## Distribution network instance 1 (all data preparation except for multinetwork_data() call)

d_file     = "test/data/combined_td_model/d_cigre.m" # Input case for distribution networks
scale_load = 1.0 # Scaling factor of loads
scale_gen  = 1.0 # Scaling factor of generators

d_data_1 = _PM.parse_file(d_file)
_FP.add_storage_data!(d_data_1)
_FP.add_flexible_demand_data!(d_data_1)
_FP.scale_cost_data!(d_data_1, scenario)
d_extradata = _FP.create_profile_data_cigre_italy(d_data_1, number_of_hours; scale_load, scale_gen) # Generate hourly time profiles for loads and generators (base values from CIGRE distribution network, profiles from Italy data).
_FP.add_td_coupling_data!(t_data, d_data_1; t_bus = 1, sub_nw = 1) # The first distribution network is connected to bus 1 of transmission network.


## Distribution network instance 2 (all data preparation except for multinetwork_data() call)

d_data_2 = deepcopy(d_data_1) # For simplicity, here a second distributon network is generated by duplicating the existing one
_FP.add_td_coupling_data!(t_data, d_data_2; t_bus = 2, sub_nw = 2) # The second distribution network is connected to bus 2 of transmission network.


## Multinetwork data preparation

t_mn_data = _FP.multinetwork_data(t_data, t_extradata)
d_mn_data = _FP.multinetwork_data(d_data_1, d_extradata; nw_id_offset=t_extradata["dim"]) # For the first distribution network, nw_id_offset is needed to avoid reusing the same nw ids of transmission
d_mn_data = _FP.multinetwork_data(d_data_2, d_extradata; merge_into=d_mn_data) # For subsequent distribution networks, simply merge the new data into the current multinetwork data structure: nw ids are computed automatically


## Solve problem

result = _FP.flex_tnep(t_mn_data, d_mn_data, _PM.DCPPowerModel, _FP.BFARadPowerModel, optimizer; setting=s)
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Analyze result

t_nws = length(t_mn_data["nw"])
d_nws = length(d_mn_data["nw"])
sub_nws = d_nws ÷ t_nws

printstyled("\n\n====================   Transmission network, first period   ====================\n\n", bold=true, color=:cyan)
_PM.print_summary(result["solution"]["nw"]["1"])

for sub_nw in 1:sub_nws
    printstyled("\n\n===================   Distribution network $sub_nw, first period   ===================\n\n", bold=true, color=:cyan)
    _PM.print_summary(result["solution"]["nw"]["$(sub_nw*t_nws+1)"])
end

printstyled("\n\n==========================   Power exchange at PCCs   ==========================\n\n", bold=true, color=:cyan)
using Printf
println("Power in MW and MVar, positive if from transmission to distribution\n")
print("period ")
for sub_nw in 1:sub_nws
    @printf("%13s%10s", "p_dist$sub_nw", "q_dist$sub_nw")
end
println()
for t_nw in 1:t_nws 
    @printf("%6i:", t_nw)
    for sub_nw in 1:sub_nws
        d_nw = sub_nw * t_nws + t_nw
        t_gen = d_mn_data["nw"]["$d_nw"]["td_coupling"]["t_gen"] # Note: is defined in dist nw
        d_gen = d_mn_data["nw"]["$d_nw"]["td_coupling"]["d_gen"]
        t_mbase = t_mn_data["nw"]["$t_nw"]["gen"]["$t_gen"]["mbase"]
        d_mbase = d_mn_data["nw"]["$d_nw"]["gen"]["$d_gen"]["mbase"]
        t_res = result["solution"]["nw"]["$t_nw"]
        d_res = result["solution"]["nw"]["$d_nw"]
        t_p_in = t_res["gen"]["$t_gen"]["pg"] * t_mbase
        d_p_in = d_res["gen"]["$d_gen"]["pg"] * d_mbase
        @assert d_p_in ≈ -t_p_in
        d_q_in = d_res["gen"]["$d_gen"]["qg"] * d_mbase
        @printf("%13.3f%10.3f", d_p_in, d_q_in)
    end
    println()
end
