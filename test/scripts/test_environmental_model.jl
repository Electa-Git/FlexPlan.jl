# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP,
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
import Ipopt
import SCS
import Juniper
import Mosek
import MosekTools
import JuMP
import Gurobi
import Cbc
import JSON
import CSV

include("../io/create_profile.jl")

# Solver configurations
scs = _FP.optimizer_with_attributes(SCS.Optimizer, "max_iters"=>100000)
ipopt = _FP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0)
cbc = _FP.optimizer_with_attributes(Cbc.Optimizer, "tol"=>1e-4, "print_level"=>0)
gurobi = Gurobi.Optimizer
mosek = Mosek.Optimizer
juniper = _FP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt, "mip_solver"=>cbc, "time_limit"=>7200)

# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments for the Italian case
################# INPUT PARAMETERS ######################
number_of_hours = 20 # Number of time points
file = "./test/data/case6_all_candidates.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage
scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
scenario["sc_years"]["1"] = Dict{String, Any}()
scenario["sc_years"]["1"]["year"] = 2019
scenario["sc_years"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["sc_years"]["1"]["probability"] = 1   # 01.01.2019:00:00 in epoch time
scenario["planning_horizon"] = 1 # in years, to scale generation cost
#############################################################

data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
data, loadprofile, genprofile = create_profile_data_italy(data, scenario) # create laod and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.add_generation_emission_data!(data) # Add flexible data model


# Add emission cost
data["co2_emission_cost"] = 0.1
_FP.scale_cost_data!(data, scenario) # Scale cost data
# Put scenario data in right format
dim = number_of_hours * length(data["scenario"])
extradata = create_profile_data(dim, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type","scenario","name", "source_version", "per_unit", "co2_emission_cost"]))

# Plot all candidates pre-optimisation
plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
plot_filename = "./test/data/output_files/candidates_italy.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "add_co2_cost" => true)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)

# Plot final topology
plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
plot_filename = "./test/data/output_files/results_italy.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)