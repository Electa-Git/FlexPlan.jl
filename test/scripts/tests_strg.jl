import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels
import Ipopt
# using CPLEX
import SCS
import Juniper
import Mosek
import MosekTools
import JuMP
import Gurobi
import Cbc
import CPLEX

include("profile_data.jl")

scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


dim = 4*2
file = "case6_strg.m"
# Test 1: Line vs storage: Base case
data = _PM.parse_file(file)
_PMACDC.process_additional_data!(data)
loadprofile = ones(5, dim)

add_storage_data!(data)
extradata = create_profile_data(dim, data, loadprofile)
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
result_test1 = _PMACDC.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)

# Test 2: Line vs storage: Load at bus 5 [100, 100, 100 , 240 MW]
data = _PM.parse_file(file)
_PMACDC.process_additional_data!(data)
loadprofile = ones(5, dim)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))

add_storage_data!(data)
extradata = create_profile_data(dim, data, loadprofile)
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
result_test2 = _PMACDC.strg_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)

# Test 3: Line vs storage: Storage investment -> existing storage is out
data = _PM.parse_file(file)
_PMACDC.process_additional_data!(data)

loadprofile = ones(5, dim)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))

add_storage_data!(data)
data["storage"]["1"]["status"] = 0
extradata = create_profile_data(dim, data, loadprofile)
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
result_test3 = _PMACDC.flex_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)


# TODO
# New problem type flex_demand
# STEP 1: Demand flexibility model -> OPEX only
# -- Variable load (check PM & loadshedding OPF)
# -- Load decrease (new variable)
# -- Load shifting (2 new variables, up and down)
# -- Load curtailment (new variable, basically same as reduction but more expensive)
# -- Contraint summation of the loads (Pflex = Pref - Pnce - Pcurt + Pup - Pdown)
# -- Update power balance constraint
# -- Add time shifting constraint
# -- Add powershifting constraint (sum Pup = sum Pdown) -> integrality constraint, needs also new variable
# -- Update objective function
# -- Update data conversion
# -- .......
# STEP 2: Add capec model
# SETTINGS for the new problem types?
