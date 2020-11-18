# Run a TNEP on a distribution network (so, should the problem be called DNEP?) using the linear
# AC approximation for radial networks.


## Import packages and choose a solver

import PowerModels
const _PM = PowerModels
import FlexPlan
const _FP = FlexPlan
import Cbc
my_optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Load and preprocess data

data_file = "test/data/CIGRE_MV_benchmark_network_tnep.m"

# The argument "validate=false" is a workaround to disable PowerModels.correct_bus_types!
# function, which updates PQ buses that have an active generator to PV buses.
# This also prevents PowerModels.correct_network_data! function from running, so:
# 1. PowerModels.make_per_unit! must be called afterwards;
# 2. other useful checks are not performed: this might lead to unintended results.
network_data = _PM.parse_file(data_file; validate=false)
_PM.make_per_unit!(network_data)


## Generate model

pm = _PM.instantiate_model(network_data, _FP.LACRadPowerModel, _PM.build_tnep; ref_extensions=[_PM.ref_add_on_off_va_bounds!,_PM.ref_add_ne_branch!])


## Solve problem

result = _PM.optimize_model!(pm; optimizer=my_optimizer)

# Convert the solution data into the data model's standard space, polar voltages and rectangular power
_PM.sol_data_model!(pm, result["solution"])


## Write result

_PM.print_summary(result["solution"])
