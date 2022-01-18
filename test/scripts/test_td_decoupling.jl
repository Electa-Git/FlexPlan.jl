# Test of transmission and distribution decoupling

# Note 1
# Only distribution part is implemented at the moment: given a distribution network having some
# candidate storage / flexible loads, a set of flexibility candidates is returned.
# The entire distribution network is seen as a flexibility candidate by transmission. Multiple
# candidates related to the same distribution network represent alternative planning options, which
# vary in amount of flexibility provided and in cost.

# Note 2
# Among flexibility sources in distribution, only storage is considered at the moment.


## Import packages and choose a solver

using Memento
_LOGGER = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script, also used by included files.

import FlexPlan; const _FP = FlexPlan
include("../io/load_case.jl")
include("../io/t-d_decoupling.jl")
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Input parameters

# Test case parameters
flex_load         = false # Toggles flexibility of loads
ne_storage        =  true # Toggles candidate storage
scale_gen         =   1.0 # Scaling factor of all generators, wind included
scale_wind        =   6.0 # Further scaling factor of wind generator
scale_load        =   1.0 # Scaling factor of loads
energy_cost       =  50.0 # Cost of energy exchanged with transmission network [€/MWh]
year_scale_factor =    10 # How many years a representative year should represent
number_of_hours   =    24 # Number of hourly optimization periods
start_period      =     1 # First period of profile data to use

# Procedure parameters
number_of_candidates = 4 # Number of flexibility candidates for each distribution network to be returned

# Script parameters
out_dir = "./test/data/output_files/td_decoupling/" # Directory of output files
plot = true # Toggles plotting of results


## Load distribution network instance

d_mn_data = load_cigre_mv_eu(; flex_load, ne_storage, scale_gen, scale_wind, scale_load, energy_cost, year_scale_factor, number_of_hours, start_period)


## Solve problem

dist_candidates = _FP.solve_td_coupling_distribution(d_mn_data; optimizer, number_of_candidates)


## Result analysis and output

# Candidates to be processed and plotted. Passing a subset of candidates can be useful in making plots less crowded. Order of candidates is respected in plots.
candidate_ids = sort(collect(keys(dist_candidates)))

mkpath(out_dir)

# Default Plots backend can be changed here
#import Plots
#Plots.plotlyjs()

# Kwargs: `plot_ext` can be used to set plot file extension; also all Plots kwargs are accepted. Example: `plot_ext="png", dpi=300`
report_dist_candidates_pcc_power(dist_candidates, out_dir; plot, candidate_ids)
report_dist_candidates_branch(dist_candidates, out_dir, d_mn_data; plot, candidate_ids)
report_dist_candidates_storage(dist_candidates, out_dir; plot, candidate_ids)

report_dist_candidates_investment(dist_candidates, out_dir; candidate_ids)
report_dist_candidates_cost(dist_candidates, out_dir; candidate_ids)
#report_dist_candidates_nw_summary(dist_candidates, out_dir)

println("Test completed. Results saved in $out_dir")
