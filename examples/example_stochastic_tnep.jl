# Example script to run multi-period optimization of demand flexibility, AC & DC lines and storage investments for the Italian case


## Import relevant packages

import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
include(joinpath(_FP_dir,"test/io/create_profile.jl")) # Include sample data from FlexPlan repository; you can of course also use your own data

# Add solver packages
# > Note: solver packages are needed to handle communication between the solver and JuMP;
# > the commercial ones do not include the solver itself.
import HiGHS
optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
#import CPLEX
#optimizer = _FP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput"=>0)


## Input parameters

number_of_hours = 24 # Number of time points
planning_horizon = 10 # Years to scale generation costs
file = joinpath(_FP_dir,"test/data/case6/case6_2030.m") # Input case, in Matpower m-file format: here 6-bus case with candidate AC, DC lines and candidate storage
scenario_properties = Dict(
    1 => Dict{String,Any}("probability"=>0.5, "start"=>1514764800000), # 1514764800000 is 2018-01-01T00:00, needed by `create_profile_data_italy!` when `mc=false`
    2 => Dict{String,Any}("probability"=>0.5, "start"=>1546300800000), # 1546300800000 is 2019-01-01T00:00, needed by `create_profile_data_italy!` when `mc=false`
)
scenario_metadata = Dict{String,Any}("mc"=>false) # Needed by `create_profile_data_italy!`
out_dir = mkpath("output")


## Load test case

data = _FP.parse_file(file) # Parse input file to obtain data dictionary
_FP.add_dimension!(data, :hour, number_of_hours) # Add dimension, e.g. hours
_FP.add_dimension!(data, :scenario, scenario_properties; metadata=scenario_metadata) # Add dimension, e.g. scenarios
_FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>planning_horizon)) # Add_dimension, e.g. years
_FP.scale_data!(data) # Scale investment & operational cost data based on planning years & hours
data, loadprofile, genprofile = create_profile_data_italy!(data) # Load time series data based demand and RES profiles of the six market zones in Italy from the data folder
time_series = create_profile_data(number_of_hours*_FP.dim_length(data,:scenario), data, loadprofile, genprofile) # Create time series data to be passed to the data dictionay
mn_data = _FP.make_multinetwork(data, time_series) # Create the multinetwork data dictionary


## Plot all candidates pre-optimization

plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
plot_filename = joinpath(out_dir,"candidates_italy.kml")
_FP.plot_geo_data(mn_data, plot_filename, plot_settings)


## Solve the planning problem

# PowerModels(ACDC) and FlexPlan settings
s = Dict("conv_losses_mp" => false, "add_co2_cost" => false)

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
println("Solving planning problem...")
result = _FP.stoch_flex_tnep(mn_data, _PM.DCPPowerModel, optimizer; setting = s)


## Plot final topology

plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
plot_filename = joinpath(out_dir,"stoch.kml")
_FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)


println("Test completed")
