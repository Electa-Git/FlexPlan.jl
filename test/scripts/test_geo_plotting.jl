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
import Mosek
import MosekTools
import JuMP
import Gurobi
import Cbc
import CPLEX

# Solver configurations
scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments 
# Input parameters
dim = 4 # Number of time points
file = "./test/data/case6_geo.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage


# Test 1: Line vs storage: Base case Load at bus 5 [240, 240, 240 , 240] MW over time
data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)

data["bus"]["1"]["lat"] = 45.3411; data["bus"]["1"]["lon"] =  9.9489;  #Italy north
data["bus"]["2"]["lat"] = 43.4894; data["bus"]["2"]["lon"] =  11.7946; #Italy central north
data["bus"]["3"]["lat"] = 41.8218; data["bus"]["3"]["lon"] =   13.8302; #Italy central south
data["bus"]["4"]["lat"] = 40.5228; data["bus"]["4"]["lon"] =   16.2155; #Italy south
data["bus"]["5"]["lat"] = 37.4844; data["bus"]["5"]["lon"] =   14.1568; # Sicily
data["bus"]["6"]["lat"] = 40.1717; data["bus"]["6"]["lon"] =   9.0738; # Sardinia


_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
loadprofile = ones(5, dim) # Create a load profile: In this case there are 5 loads in the test case

extradata = _FP.create_profile_data(dim, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

plot_settings = Dict("add_nodes" => true)
plot_filename = "./test/data/output_files/test_plot.kml"

_FP.plot_geo_data(mn_data, plot_filename, plot_settings)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments

result_test1 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)
