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

import FlexPlan; const _FP = FlexPlan
include("../io/create_profile.jl")
include("../io/t-d_decoupling.jl")
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Input parameters

planning_horizon     =    10 # In years, to scale costs
number_of_hours      =    24 # Number of hourly optimization periods
start_period         =     1 # First period of profile data to use
d_file               = "test/data/combined_td_model/d_cigre_more_storage.m" # Input case for distribution network
energy_cost          =  50.0 # Cost of energy exchanged with transmission network [€/MWh]
scale_gen            =   1.0 # Scaling factor of all generators
scale_wind           =   6.0 # Scaling factor of wind generator
scale_load           =   1.0 # Scaling factor of loads
flex_load            = false # Toggles flexibility of loads
ne_storage           =  true # Toggles candidate storage
number_of_candidates =     4 # Number of flexibility candidates for each distribution network to be returned
out_dir              = "./test/data/output_files/td_decoupling/" # Directory of output files
plot                 =  true # Toggles plotting of results


## Scenario

scenario = Dict{String, Any}(
    "hours" => number_of_hours,
    "planning_horizon" => planning_horizon
)


## Distribution network instance

d_data = _FP.parse_file(d_file)
_FP.add_dimension!(d_data, :hour, number_of_hours)
_FP.add_dimension!(d_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)), metadata = Dict{String,Any}("mc"=>true))
_FP.add_dimension!(d_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>planning_horizon))
_FP.add_dimension!(d_data, :sub_nw, 1)

# Set cost of energy exchanged with transmission network
d_data["gen"]["14"]["ncost"] = 2
d_data["gen"]["14"]["cost"] = [energy_cost, 0.0]

# Scale wind generation
d_data["gen"]["6"]["pmin"] *= scale_wind
d_data["gen"]["6"]["pmax"] *= scale_wind
d_data["gen"]["6"]["qmin"] *= scale_wind
d_data["gen"]["6"]["qmax"] *= scale_wind

# Toggle flexible demand
for (l, load) in d_data["load"]
    load["flex"] = flex_load ? 1 : 0
end

# Toggle candidate storage
if !ne_storage
    d_data["ne_storage"] = Dict{String,Any}()
end

_FP.scale_data!(d_data)
_FP.add_td_coupling_data!(d_data; sub_nw = 1)
d_time_series = create_profile_data_cigre(d_data, number_of_hours; start_period, scale_load, scale_gen) # Generate hourly time profiles for loads and generators, based on CIGRE benchmark distribution network.
d_mn_data = _FP.make_multinetwork(d_data, d_time_series)


## Solve problem

dist_candidates = _FP.solve_td_coupling_distribution(d_data, d_mn_data; optimizer, number_of_candidates)


## Result analysis and output

# Candidates to be processed and plotted. Passing a subset of candidates can be useful in making plots less crowded. Order of candidates is respected in plots.
candidate_ids = sort(collect(keys(dist_candidates)))

mkpath(out_dir)

# Default Plots backend can be changed here
#import Plots
#Plots.plotlyjs()

# Kwargs: `plot_ext` can be used to set plot file extension; also all Plots kwargs are accepted. Example: plot_ext="png", dpi=300
report_dist_candidates_pcc_power(dist_candidates, out_dir; plot, candidate_ids)
report_dist_candidates_branch(dist_candidates, out_dir, d_data; plot, candidate_ids)
report_dist_candidates_storage(dist_candidates, out_dir; plot, candidate_ids)

report_dist_candidates_investment(dist_candidates, out_dir; candidate_ids)
report_dist_candidates_cost(dist_candidates, out_dir; candidate_ids)
#report_dist_candidates_nw_summary(dist_candidates, out_dir)

println("Test completed. Results saved in $out_dir")
