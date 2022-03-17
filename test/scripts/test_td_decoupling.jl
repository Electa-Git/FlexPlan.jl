# Test of transmission and distribution decoupling

# T&D decoupling procedure
# 1. Compute a surrogate model of distributon networks
# 2. Optimize planning of transmission network using surrogate distribution nwtorks [not implemented yet]
# 3. Fix power exchanges between T&D and optimize planning of distribution networks [not implemented yet]


## Import packages and choose a solver

using Memento
_LOGGER = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script, also used by included files.

import PowerModels; const _PM = PowerModels
import FlexPlan; const _FP = FlexPlan
include("../io/load_case.jl")
include("../io/sol.jl")
include("../io/td_decoupling.jl")
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


# Script parameters

out_dir = "./test/data/output_files/td_decoupling/" # Directory of output files


## Load distribution network instance

# To find out the meaning of the parameters, consult the function documentation
#d_mn_data = load_cigre_mv_eu(flex_load=false, ne_storage=true, scale_gen=1.0, scale_wind=6.0, scale_load=1.0, energy_cost=50.0, year_scale_factor=10, number_of_hours=24, start_period=1)
d_mn_data = load_ieee_33(number_of_hours=24, number_of_scenarios=2)

# For each storage element, temporarily set the external process power to zero
for nw in values(d_mn_data["nw"])
    for comp in ["storage", "ne_storage"]
        for st in values(nw[comp])
            st["stationary_energy_inflow"] = 0.0
            st["stationary_energy_outflow"] = 0.0
        end
    end
end


## Compute surrogate model of distribution network

#surrogate_dist = _FP.surrogate_model!(d_mn_data; optimizer)

# Two-step alternative
sol_up, sol_base, sol_down = _FP.TDDecoupling.probe_distribution_flexibility!(d_mn_data; optimizer)
surrogate_dist = _FP.TDDecoupling.calc_surrogate_model(d_mn_data, sol_up, sol_base, sol_down; standalone=true)


## Analyze results

# Report intermediate solutions used for building the surrogate model

for (sol,name) in [(sol_up,"up"), (sol_base,"base"), (sol_down,"down")]
    out_subdir = mkpath(joinpath(out_dir, name))
    sol_report_cost_summary(sol, d_mn_data; out_dir=out_subdir, table="t_cost.csv", plot="cost.pdf")
    sol_report_power_summary(sol, d_mn_data; out_dir=out_subdir, table="t_power.csv", plot="power.pdf")
    sol_report_branch(sol, d_mn_data; rated_power_scale_factor=cos(π/8), out_dir=out_subdir, table="t_branch.csv", plot="branch.pdf") # `cos(π/8)` is due to octagonal approximation of apparent power in `_FP.BFARadPowerModel`
    sol_report_bus_voltage_magnitude(sol, d_mn_data; out_dir=out_subdir, table="t_bus.csv", plot="bus.pdf")
    sol_report_gen(sol, d_mn_data; out_dir=out_subdir, table="t_gen.csv", plot="gen.pdf")
    sol_report_load(sol, d_mn_data; out_dir=out_subdir, table="t_load.csv", plot="load.pdf")
    sol_report_load_summary(sol, d_mn_data; out_dir=out_subdir, table="t_load_summary.csv", plot="load_summary.pdf")
    if name == "base"
        sol_report_investment_summary(sol, d_mn_data; out_dir=out_subdir, table="t_investment_summary.csv", plot="investment_summary.pdf")
        sol_report_storage(sol, d_mn_data; out_dir=out_subdir, table="t_storage.csv", plot="storage.pdf")
        sol_report_storage_summary(sol, d_mn_data; out_dir=out_subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")
    end
    sol_graph(sol, d_mn_data; plot="map.pdf", out_dir=out_subdir, hour=1, year=1) # Just as an example; dimension coordinates can also be vectors, or be omitted, in which case one plot for each coordinate will be generated.
end

# Probe the flexibility provided by the surrogate model and report results

sol_report_decoupling_pcc_power(sol_up, sol_base, sol_down, d_mn_data, surrogate_dist, optimizer; out_dir, table="t_pcc_power.csv", plot="pcc_power.pdf")

sol_surr = _FP.TDDecoupling.run_td_decoupling_model(surrogate_dist, _FP.post_simple_stoch_flex_tnep, optimizer)
surrogate_subdir = mkpath(joinpath(out_dir, "surrogate"))
sol_report_cost_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_cost.csv", plot="cost.pdf")
sol_report_power_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_power.csv", plot="power.pdf")
sol_report_gen(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_gen.csv", plot="gen.pdf")
sol_report_load_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_load_summary.csv", plot="load_summary.pdf")
sol_report_storage_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")

println("Test completed. Results saved in $out_dir")
