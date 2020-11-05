# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels

include("../../src/io/plot_flex_demand.jl")

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP, 
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
#import Ipopt
#import SCS
#import Juniper
#import Mosek
#import MosekTools
import JuMP
#import Gurobi
import Cbc
#import CPLEX

# Solver configurations
#scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
#ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
#cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
#gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
#mosek = JuMP.with_optimizer(Mosek.Optimizer)
#juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments 

# Input parameters:
number_of_hours = 24        # Number of time steps
start_hour = 1              # First time step
n_loads = 5                 # Number of load points
i_load_mod = 5              # The load point on which we modify the demand profile

file = "./test/data/case6_flex.m" # Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines, flexible demand and candidate storage

loadprofile = 0.1 .* ones(n_loads, number_of_hours) # Create a load profile: In this case there are 5 loads in the test case
t_vec = start_hour:start_hour+(number_of_hours-1)

# Manipulate load profile: Load number 5 changes over time: Orignal load is 240 MW.
load_mod_mean = 120
load_mod_var = 120
loadprofile[i_load_mod,:] = ( load_mod_mean .+ load_mod_var .* sin.(t_vec * 2*pi/24) )/240 

# Data manipulation (per unit conversions and matching data models)
data = _PM.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_flexible_demand_data!(data) # Add flexible data model


extradata = _FP.create_profile_data(number_of_hours, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# Plot branch flows to bus 5
p_flow_1 = plot_branch_flow(result_test1,1,data,"branchdc")
p_flow_2 = plot_branch_flow(result_test1,2,data,"branchdc")
savefig(p_flow_1,"branch_flow_1")
savefig(p_flow_2,"branch_flow_2")

# Check if new DC branch is built and plot flow
p_flow_ne = plot_branch_flow(result_test1,3,data,"branchdc_ne")
savefig(p_flow_ne,"ne_branch_flow")

# Check if new AC branch is built
plot_branch_flow(result_test1,1,data,"ne_branch")

# Plot exemplary (flexible) load
p_flex = plot_flex_demand(result_test1,5,data,extradata)
savefig(p_flex,"flex_demand")