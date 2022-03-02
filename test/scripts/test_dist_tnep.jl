# Single-period network expansion planning using the distribution network model


## Import packages and choose a solver

import PowerModels; const _PM = PowerModels
import FlexPlan; const _FP = FlexPlan
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Load and preprocess data

data_file = "test/data/CIGRE_MV_benchmark_network_tnep.m"
data = _FP.parse_file(data_file)


## Solve problem

result = _FP.tnep_rad(data, _FP.BFARadPowerModel, optimizer)
# Two-step alternative
#pm = _PM.instantiate_model(data, _FP.BFARadPowerModel, _FP.build_tnep_rad; ref_extensions=[_FP.ref_add_gen!, _PM.ref_add_on_off_va_bounds!,_FP.ref_add_ne_branch_allbranches!,_FP.ref_add_frb_branch!,_FP.ref_add_oltc_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer, solution_processors=[_PM.sol_data_model!])
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Write result

_PM.print_summary(result["solution"])
