# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

include("../io/create_profile.jl")

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
scs = _FP.optimizer_with_attributes(SCS.Optimizer, "max_iters"=>100000)
ipopt = _FP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0)
cplex = CPLEX.Optimizer
cbc = _FP.optimizer_with_attributes(Cbc.Optimizer, "tol"=>1e-4, "print_level"=>0)
gurobi = Gurobi.Optimizer
mosek = Mosek.Optimizer
juniper = _FP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt, "mip_solver"=>cbc, "time_limit"=>7200)


# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments
# Input parameters
dim = 4 # Number of time points
file = "./test/data/case6_strg.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage


# Test 1: Line vs storage: Base case Load at bus 5 [240, 240, 240 , 240] MW over time
data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
loadprofile = ones(5, dim) # Create a load profile: In this case there are 5 loads in the test case


extradata = create_profile_data(dim, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments

result_test1 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)

# Test 2: Line vs storage: Load at bus 5 [100, 100, 100 , 240] MW over time
data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
loadprofile = ones(5, dim) # Create a load profile: In this case there are 5 loads in the test case
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))


extradata = create_profile_data(dim, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result_test2 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)

# Test 3: Line vs storage: Storage investment -> existing storage is out of service "status" = 0
data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
data["storage"]["1"]["status"] = 0 # take existing storage out of service
loadprofile = ones(5, dim) # Create a load profile: In this case there are 5 loads in the test case
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))


extradata = create_profile_data(dim, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result_test3 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)
