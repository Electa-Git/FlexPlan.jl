# Example script to test the branch replacement feature in multi-period optimization of demand flexibility, AC & DC lines and storage investments


## Import relevant packages

import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC # For DC grid
import PowerModels; const _PM = PowerModels # For AC grid and common functions

# Include sample data from FlexPlan repository; you can of course also use your own data
include("../io/create_profile.jl")

# Add solver packages
# > Note: solver packages are needed to handle communication between the solver and JuMP;
# > the commercial ones do not include the solver itself.
import Cbc
#import Ipopt
#import Juniper
#import SCS
#import Mosek
#import Gurobi

# Solver configuration
cbc = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
#ipopt = _FP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0)
#juniper = _FP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt, "mip_solver"=>cbc, "time_limit"=>7200)
#scs = _FP.optimizer_with_attributes(SCS.Optimizer, "max_iters"=>100000)
#gurobi = Gurobi.Optimizer
#mosek = Mosek.Optimizer
optimizer = cbc


## Input parameters

number_of_hours = 24 # Number of time points
planning_horizon = 10 # Years to scale generation costs
file = "./test/data/case6_replacement.m" # Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage
scenario_properties = Dict(
    1 => Dict{String,Any}("probability"=>0.5, "start"=>1514764800000), # 1514764800000 is 2018-01-01T00:00, needed by `create_profile_data_italy!` when `"mc"=false`
    2 => Dict{String,Any}("probability"=>0.5, "start"=>1546300800000), # 1546300800000 is 2019-01-01T00:00, needed by `create_profile_data_italy!` when `"mc"=false`
)
scenario_metadata = Dict{String,Any}("mc"=>false) # Needed by `create_profile_data_italy!`


## Load test case

data = _FP.parse_file(file) # Parse input file to obtain data dictionary
_FP.add_dimension!(data, :hour, number_of_hours) # Add dimension, e.g. hours
_FP.add_dimension!(data, :scenario, scenario_properties; metadata=scenario_metadata) # Add dimension, e.g. scenarios
_FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>planning_horizon)) # Add_dimension, e.g. years
_FP.scale_data!(data) # Scale investment & operational cost data based on planning years & hours
data, loadprofile, genprofile = create_profile_data_italy!(data) # Load time series data based demand and RES profiles of the six market zones in Italy from the data folder
time_series = create_profile_data(number_of_hours*_FP.dim_length(data,:scenario), data, loadprofile, genprofile) # Create time series data to be passed to the data dictionay
mn_data = _FP.make_multinetwork(data, time_series) # Create the multinetwork data dictionary


## Solve the planning problem

# PowerModels(ACDC) and FlexPlan settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "allow_line_replacement" => true)

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
println("Solving planning problem...")
result = _FP.simple_stoch_flex_tnep(mn_data, _PM.DCPPowerModel, optimizer; setting = s)


println("Test completed")
