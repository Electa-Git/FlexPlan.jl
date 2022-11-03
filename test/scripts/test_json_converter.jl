# Test the JSON converter functionality

## Import packages

import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
import HiGHS
optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)


## Script parameters

file = "test/data/json_converter/case6_input_file_2018-2019.json"


## Parse the JSON file to easily check the input

#import JSON
#d = JSON.parsefile(file)


## Convert JSON file

mn_data = _FP.convert_JSON(file) # Conversion caveats and function parameters: see function documentation


## Instantiate model and solve network expansion problem

# Transmission network

setting = Dict("conv_losses_mp" => true)
result = _FP.simple_stoch_flex_tnep(mn_data, _PM.DCPPowerModel, optimizer; setting)
# Two-step alternative: exposes `pm`
#pm = _PM.instantiate_model(mn_data, _PM.DCPPowerModel, _FP.build_simple_stoch_flex_tnep; setting, ref_extensions=[_FP.ref_add_gen!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer)

# Distribution network

#result = _FP.simple_stoch_flex_tnep(mn_data, _FP.BFARadPowerModel, optimizer)
# Two-step alternative: exposes `pm`
#pm = _PM.instantiate_model(mn_data, _FP.BFARadPowerModel, _FP.build_simple_stoch_flex_tnep; ref_extensions=[_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!])
#result = _PM.optimize_model!(pm; optimizer=optimizer, solution_processors=[_PM.sol_data_model!])


println("Test completed")
