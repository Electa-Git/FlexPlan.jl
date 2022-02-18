# Test of transmission and distribution decoupling

# T&D decoupling procedure
# 1. Compute a surrogate model of distributon networks [partly implemented]
# 2. Optimize planning of transmission network using surrogate distribution nwtorks [not implemented yet]
# 3. Fix power exchanges between T&D and optimize planning of distribution networks [not implemented yet]


## Import packages and choose a solver

using Memento
_LOGGER = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script, also used by included files.

import PowerModels; const _PM = PowerModels
import FlexPlan; const _FP = FlexPlan
include("../io/load_case.jl")
include("../io/td_decoupling.jl")
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


# Script parameters

out_dir = "./test/data/output_files/td_decoupling/" # Directory of output files
plot = true # Toggles plotting of results


## Load distribution network instance

# To find out the meaning of the parameters, consult the function documentation
#d_mn_data = load_cigre_mv_eu(flex_load=false, ne_storage=true, scale_gen=1.0, scale_wind=6.0, scale_load=1.0, energy_cost=50.0, year_scale_factor=10, number_of_hours=24, start_period=1)
d_mn_data = load_ieee_33(number_of_hours=24, number_of_scenarios=1)


## Solve problem

flex_result = _FP.probe_distribution_flexibility!(d_mn_data; optimizer)


## Result analysis and output

mkpath(out_dir)

# Default Plots backend can be changed here
#import Plots
#Plots.plotlyjs()

# Kwargs: `plot_ext` can be used to set plot file extension; also all Plots kwargs are accepted. Example: `plot_ext="png", dpi=300`
report_flex_pcc_power(flex_result, out_dir; plot)
report_flex_branch(flex_result, out_dir, d_mn_data; plot)
report_flex_storage(flex_result, out_dir; plot)

report_flex_investment(flex_result, out_dir)
#report_flex_nw_summary(flex_result, out_dir)

println("Test completed. Results saved in $out_dir")
