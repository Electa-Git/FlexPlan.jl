import FlexPlan as _FP
import HiGHS

const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package

milp_optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)

data = _FP.parse_file(normpath(_FP_dir, "test", "data", "cigre_mv_eu", "cigre_mv_eu_unit_test.m"))
_FP.add_dimension!(data, :hour, 1)
_FP.add_dimension!(data, :year, 1)
data = _FP.make_multinetwork(data)
result = _FP.flex_tnep(data, _FP.BFA8PowerModel, milp_optimizer)


## Result analysis

import PowerModels as _PM
_PM.print_summary(result["solution"]["nw"]["1"])

println("\nTest completed")
