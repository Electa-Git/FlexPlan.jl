# Optimal power flow using the distribution network model


## Import packages and choose a solver

import PowerModels
const _PM = PowerModels
import FlexPlan
const _FP = FlexPlan
import Ipopt
optimizer = _FP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "sb"=>"yes")


## Load and preprocess data

data_file = "test/data/CIGRE_MV_benchmark_network_with_costs.m"

# The argument "validate=false" is a workaround to disable PowerModels.correct_bus_types! function,
# which updates PQ buses that have an active generator to PV buses.
# This also prevents PowerModels.correct_network_data! function from running, so:
# 1. PowerModels.make_per_unit! must be called afterwards;
# 2. other useful checks are not performed: this might lead to unintended results.
network_data = _PM.parse_file(data_file; validate=false)
_PM.make_per_unit!(network_data)


## Solve problem

result = _FP.opf_rad(network_data, _FP.BFARadPowerModel, optimizer)
# Two-step alternative
#pm = _PM.instantiate_model(network_data, _FP.BFARadPowerModel, _FP.build_opf_rad; ref_extensions=[_FP.ref_add_frb_branch!,_FP.ref_add_oltc_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer, solution_processors=[_PM.sol_data_model!])
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Write result

_PM.print_summary(result["solution"])
