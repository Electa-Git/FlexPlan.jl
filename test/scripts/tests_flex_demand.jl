import FlexPlan; const _FP = FlexPlan
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

scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


dim = 4
file = "./test/data/case6_flex.m"
# Test 1: Line vs storage: Base case
data = _PM.parse_file(file)
_PMACDC.process_additional_data!(data)
loadprofile = ones(5, dim)

_FP.add_storage_data!(data)
_FP.add_flexible_demand_data!(data)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))
extradata = _FP.create_profile_data(dim, data, loadprofile)
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)



# TODO
# New problem type flex_demand
# STEP 1: Demand flexibility model -> OPEX only
# -- Add time shifting constraint
# -- .......
# SETTINGS for the new problem types?
