# Test the JSON converter functionality

## Import packages

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, # Options: <https://github.com/jump-dev/Cbc.jl#options>
    "logLevel" => 0,
)


## Script parameters

file = "test/data/json_converter/case6_input_file_2018-2019.json"


## Parse the JSON file to easily check the input

#import JSON
#d = JSON.parsefile(file)


## Convert JSON file

mn_data = _FP.convert_JSON(file) # Conversion caveats and function parameters: see function documentation


## Instantiate model and solve network expansion problem

# Transmission network

result = _FP.stoch_flex_tnep(mn_data, _PM.DCPPowerModel, optimizer)
# Two-step alternative: exposes `pm`
#pm = _PM.instantiate_model(mn_data, _PM.DCPPowerModel, _FP.post_stoch_flex_tnep; ref_extensions=[_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, _FP.add_candidate_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer)

# Distribution network

#result = _FP.stoch_flex_tnep(mn_data, _FP.BFARadPowerModel, optimizer)
# Two-step alternative: exposes `pm`
#pm = _PM.instantiate_model(mn_data, _FP.BFARadPowerModel, _FP.post_stoch_flex_tnep; ref_extensions=[_FP.add_candidate_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer, solution_processors=[_PM.sol_data_model!])


println("Test completed")
