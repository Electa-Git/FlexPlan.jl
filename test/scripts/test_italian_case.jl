# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP,
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
import Ipopt
import SCS
import Juniper
#import Mosek
#import MosekTools
import JuMP
#import Gurobi
import Cbc
import JSON
import CSV

# Solver configurations
scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
#gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
#mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)

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
data, loadprofile, genprofile = _FP.create_profile_data_italy(data, scenario) # create laod and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data

dim = number_of_hours * length(data["scenario"])
extradata = _FP.create_profile_data(dim, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type","scenario","name", "source_version", "per_unit"]))

# Plot all candidates pre-optimisation
plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
plot_filename = "./test/data/output_files/candidates_italy.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# plot load and gen data + storage data
p1 = _FP.plot_profile_data(extradata, number_of_hours, result["solution"], ["3","5","6"])
p2,p3 = _FP.plot_storage_data(data,result["solution"])
p = plot(p1,p2,p3,layout=(3,1),size=(1200,1050),xticks = 0:50:number_of_hours)
#savefig(p,"./test/data/output_files/load_gen_strg.png")
display(p)

# Plot final topology
plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
plot_filename = "./test/data/output_files/results_italy.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)
