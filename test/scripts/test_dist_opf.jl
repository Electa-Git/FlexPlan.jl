# Optimal power flow using the linear AC approximation for radial networks


## Import packages and choose a solver

import PowerModels
const _PM = PowerModels
import FlexPlan
const _FP = FlexPlan
import Ipopt
my_optimizer = _FP.optimizer_with_attributes(Ipopt.Optimizer, "print_level"=>0, "sb"=>"yes")


## Load and preprocess data

data_file = "test/data/CIGRE_MV_benchmark_network_with_costs.m"

# The argument "validate=false" is a workaround to disable PowerModels.correct_bus_types! function,
# which updates PQ buses that have an active generator to PV buses.
# This also prevents PowerModels.correct_network_data! function from running, so:
# 1. PowerModels.make_per_unit! must be called afterwards;
# 2. other useful checks are not performed: this might lead to unintended results.
network_data = _PM.parse_file(data_file; validate=false)
_PM.make_per_unit!(network_data)


## Generate model

pm = _PM.instantiate_model(network_data, _FP.BFARadPowerModel, _PM.build_opf_bf)


## Solve problem

result = _PM.optimize_model!(pm; optimizer=my_optimizer)
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"

# Convert the solution data into the data model's standard space, polar voltages and rectangular power
_PM.sol_data_model!(pm, result["solution"])


## Compare result to AC OPF

pm_benchmark = _PM.instantiate_model(network_data, _PM.ACPPowerModel, _PM.build_opf)
result_benchmark = _PM.optimize_model!(pm_benchmark; optimizer=my_optimizer)
@assert result_benchmark["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result_benchmark["optimizer"]) termination status: $(result_benchmark["termination_status"])"

printstyled("AC OPF\n\n"; color=:bold)
_PM.print_summary(result_benchmark["solution"])

printstyled("\n\nLinear AC approximation for radial networks\n\n"; color=:bold)
_PM.print_summary(result["solution"])
