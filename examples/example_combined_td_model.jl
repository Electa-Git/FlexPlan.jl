# Test of the transmission and distribution combined model


## Import packages

using Memento
_LOGGER = Logger(first(splitext(basename(@__FILE__)))) # A logger for this script, also used by included files.

import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
include(joinpath(_FP_dir,"test/io/load_case.jl")) # Include sample data from FlexPlan repository; you can of course also use your own data


## Set up solver

import HiGHS
optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
#import CPLEX
#optimizer = _FP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput"=>0)
direct_model = false # Whether to construct JuMP models using JuMP.direct_model() instead of JuMP.Model(). direct_model is only supported by some solvers.


## Set script parameters

number_of_hours = 4
number_of_scenarios = 2
number_of_years = 1
t_model_type = _PM.DCPPowerModel
d_model_type = _FP.BFARadPowerModel
t_setting = Dict("output" => Dict("branch_flows"=>true), "conv_losses_mp" => false)
d_setting = Dict{String,Any}()


## Set up logging

setlevel!.(Memento.getpath(getlogger(_FP)), "debug") # FlexPlan logger verbosity level. Useful values: "info", "debug", "trace"
time_start = time()


## Load data

# JSON files containing either transmission or distribution networks can be loaded with
# `data = _FP.convert_JSON(file_path)`; those containing both transmission and distribution
# networks can be loaded with `t_data, d_data = _FP.convert_JSON_td(file_path)`.

# Transmission network data
t_data = load_case6(; number_of_hours, number_of_scenarios, number_of_years)

# Distribution network 1 data
d_data_sub_1 = load_ieee_33(; number_of_hours, number_of_scenarios, number_of_years)
d_data_sub_1["t_bus"] = 3 # States that this distribution network is attached to bus 3 of transmission network

# Distribution network 2 data
d_data_sub_2 = deepcopy(d_data_sub_1)
d_data_sub_2["t_bus"] = 6

d_data = [d_data_sub_1, d_data_sub_2]


## Solve problem

result = _FP.simple_stoch_flex_tnep(t_data, d_data, t_model_type, d_model_type, optimizer; t_setting, d_setting, direct_model)
@assert result["termination_status"] ∈ (_FP.OPTIMAL, _FP.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"

notice(_LOGGER, "Script completed in $(round(time()-time_start;sigdigits=3)) seconds.")
