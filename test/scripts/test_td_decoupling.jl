# Test of transmission and distribution decoupling

# T&D decoupling procedure
# 1. Compute a surrogate model of distributon networks
# 2. Optimize planning of transmission network using surrogate distribution networks
# 3. Fix power exchanges between T&D and optimize planning of distribution networks


## Import packages

using Dates
using Memento
_LOGGER = Logger(first(splitext(basename(@__FILE__)))) # A logger for this script, also used by included files.

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
include("../io/load_case.jl")
include("../io/sol.jl")
include("../io/td_decoupling.jl")


## Set up solver

import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0, "threads"=>Threads.nthreads())
#import CPLEX
#optimizer = _FP.optimizer_with_attributes(CPLEX.Optimizer, "CPXPARAM_ScreenOutput"=>0)
direct_model = false # Whether to construct JuMP models using JuMP.direct_model() instead of JuMP.Model(). direct_model is only supported by some solvers.


## Set script parameters

number_of_hours = 24
number_of_scenarios = 1
number_of_years = 1
number_of_distribution_networks = 2
t_model_type = _PM.DCPPowerModel
d_model_type = _FP.BFARadPowerModel
build_method = _FP.post_simple_stoch_flex_tnep
t_ref_extensions = [_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!]
d_ref_extensions = [_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!]
t_solution_processors = [_PM.sol_data_model!]
d_solution_processors = [_PM.sol_data_model!, _FP.sol_td_coupling!]
t_setting = Dict("output" => Dict("branch_flows"=>true), "conv_losses_mp" => false)
d_setting = Dict{String,Any}()
cost_scale_factor = 1e-6
out_dir = mkpath("./test/data/output_files/td_decoupling/") # Directory of output files

report_intermediate_results = false
report_result = false
compare_with_combined_td_model = true

## Set up logging

setlevel!.(Memento.getpath(getlogger(_PM)), "notice") # PowerModels logger verbosity level. Useful values: "error", "warn", "notice", "info"
setlevel!.(Memento.getpath(getlogger(_FP)), "debug") # FlexPlan logger verbosity level. Useful values: "info", "debug", "trace"
info(_LOGGER, "Now is: $(now(UTC)) (UTC)")
time_start = time()


## Load data

# Transmission network data

t_data = load_case6(; number_of_hours, number_of_scenarios, number_of_years, cost_scale_factor, share_data=false)

# Distribution network data

d_data_sub = load_ieee_33(; number_of_hours, number_of_scenarios, cost_scale_factor, number_of_years)
# Alternative distribution network. It has only 1 scenario and 1 year.
#d_data_sub = load_cigre_mv_eu(flex_load=false, ne_storage=true, scale_gen=1.0, scale_wind=6.0, scale_load=1.0, energy_cost=50.0, year_scale_factor=10, number_of_hours, start_period=1)

# For each storage element, temporarily set the external process power to zero (required by the decoupling procedure at the moment)
for nw in values(d_data_sub["nw"])
    for comp in ["storage", "ne_storage"]
        for st in values(nw[comp])
            st["stationary_energy_inflow"] = 0.0
            st["stationary_energy_outflow"] = 0.0
        end
    end
end

d_data = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
transmission_ac_buses = length(first(values(t_data["nw"]))["bus"])
for s in 1:number_of_distribution_networks
    d_data[s] = deepcopy(d_data_sub)
    _FP.dim_prop(d_data[s], :sub_nw, 1)["t_bus"] = mod1(s, transmission_ac_buses) # Attach distribution network to a transmission network bus
end


## Compute optimal planning using T&D decoupling procedure

info(_LOGGER, "Solving planning problem using T&D decoupling...")
result_decoupling = _FP.run_td_decoupling!(
    t_data, d_data, t_model_type, d_model_type, optimizer, build_method;
    t_ref_extensions, d_ref_extensions, t_solution_processors, d_solution_processors, t_setting, d_setting, direct_model
)
info(_LOGGER, "T&D decoupling procedure took $(round(result_decoupling["solve_time"]; sigdigits=3)) seconds")


## Report results

if report_intermediate_results
    info(_LOGGER, "Reporting intermediate results of T&D decoupling procedure...")

    # Intermediate solutions used for building the surrogate model
    sol_up, sol_base, sol_down = _FP.TDDecoupling.probe_distribution_flexibility!(d_data_sub; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting, direct_model)
    intermediate_results_dir = joinpath(out_dir, "intermediate_results")
    for (sol,name) in [(sol_up,"up"), (sol_base,"base"), (sol_down,"down")]
        subdir = mkpath(joinpath(intermediate_results_dir, name))
        sol_report_cost_summary(sol, d_data_sub; out_dir=subdir, table="t_cost.csv", plot="cost.pdf")
        sol_report_power_summary(sol, d_data_sub; out_dir=subdir, table="t_power.csv", plot="power.pdf")
        sol_report_branch(sol, d_data_sub; rated_power_scale_factor=cos(π/8), out_dir=subdir, table="t_branch.csv", plot="branch.pdf") # `cos(π/8)` is due to octagonal approximation of apparent power in `_FP.BFARadPowerModel`
        sol_report_bus_voltage_magnitude(sol, d_data_sub; out_dir=subdir, table="t_bus.csv", plot="bus.pdf")
        sol_report_gen(sol, d_data_sub; out_dir=subdir, table="t_gen.csv", plot="gen.pdf")
        sol_report_load(sol, d_data_sub; out_dir=subdir, table="t_load.csv", plot="load.pdf")
        sol_report_load_summary(sol, d_data_sub; out_dir=subdir, table="t_load_summary.csv", plot="load_summary.pdf")
        if name == "base"
            sol_report_investment_summary(sol, d_data_sub; out_dir=subdir, table="t_investment_summary.csv", plot="investment_summary.pdf")
            sol_report_storage(sol, d_data_sub; out_dir=subdir, table="t_storage.csv", plot="storage.pdf")
            sol_report_storage_summary(sol, d_data_sub; out_dir=subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")
        end
        sol_graph(sol, d_data_sub; plot="map.pdf", out_dir=subdir, hour=1) # Just as an example; dimension coordinates can also be vectors, or be omitted, in which case one plot for each coordinate will be generated.
    end

    # Surrogate model
    surrogate_dist = _FP.TDDecoupling.calc_surrogate_model(d_data_sub, sol_up, sol_base, sol_down; standalone=true)
    surrogate_subdir = mkpath(joinpath(intermediate_results_dir, "surrogate"))
    sol_report_decoupling_pcc_power(sol_up, sol_base, sol_down, d_data_sub, surrogate_dist; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, out_dir=intermediate_results_dir, table="t_pcc_power.csv", plot="pcc_power.pdf")

    # Planning obtained by using the surrogate model as it were an ordinary distribution network
    sol_surr = _FP.TDDecoupling.run_td_decoupling_model(surrogate_dist; model_type=d_model_type, optimizer, build_method, ref_extensions=d_ref_extensions, solution_processors=d_solution_processors, setting=d_setting)
    sol_report_cost_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_cost.csv", plot="cost.pdf")
    sol_report_power_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_power.csv", plot="power.pdf")
    sol_report_gen(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_gen.csv", plot="gen.pdf")
    sol_report_load_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_load_summary.csv", plot="load_summary.pdf")
    sol_report_storage_summary(sol_surr, surrogate_dist; out_dir=surrogate_subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")
end

if report_result
    info(_LOGGER, "Reporting results of T&D decoupling procedure...")

    result_dir = joinpath(out_dir, "result")

    t_sol = result_decoupling["t_solution"]
    t_subdir = mkpath(joinpath(result_dir, "transmission"))
    sol_report_cost_summary(t_sol, t_data; out_dir=t_subdir, table="t_cost.csv", plot="cost.pdf")
    sol_report_power_summary(t_sol, t_data; out_dir=t_subdir, table="t_power.csv", plot="power.pdf")
    #sol_report_branch(t_sol, t_mn_data, out_dir=t_subdir, table="t_branch.csv", plot="branch.pdf") # Waiting for https://github.com/lanl-ansi/PowerModels.jl/issues/820 to be fixed (will require PowerModels 0.19.6)
    sol_report_bus_voltage_angle(t_sol, t_data; out_dir=t_subdir, table="t_bus.csv", plot="bus.pdf")
    sol_report_gen(t_sol, t_data; out_dir=t_subdir, table="t_gen.csv", plot="gen.pdf")
    sol_report_load(t_sol, t_data; out_dir=t_subdir, table="t_load.csv", plot="load.pdf")
    sol_report_load_summary(t_sol, t_data; out_dir=t_subdir, table="t_load_summary.csv", plot="load_summary.pdf")
    sol_report_investment_summary(t_sol, t_data; out_dir=t_subdir, table="t_investment_summary.csv", plot="investment_summary.pdf")
    sol_report_storage(t_sol, t_data; out_dir=t_subdir, table="t_storage.csv", plot="storage.pdf")
    sol_report_storage_summary(t_sol, t_data; out_dir=t_subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")
    # Waiting for https://github.com/lanl-ansi/PowerModels.jl/issues/820 to be fixed (will require PowerModels 0.19.6)
    #sol_graph(t_sol, t_mn_data; plot="map.pdf", out_dir=t_subdir, hour=1) # Just as an example; dimension coordinates can also be vectors, or be omitted, in which case one plot for each coordinate will be generated.

    for (s,sol) in enumerate(result_decoupling["d_solution"])
        subdir = mkpath(joinpath(result_dir, "distribution_$s"))
        sol_report_cost_summary(sol, d_data_sub; td_coupling=false, out_dir=subdir, table="t_cost.csv", plot="cost.pdf") # `td_coupling=false` because even if data dictionary specifies a positive cost it must not be considered.
        sol_report_power_summary(sol, d_data_sub; out_dir=subdir, table="t_power.csv", plot="power.pdf")
        sol_report_branch(sol, d_data_sub; rated_power_scale_factor=cos(π/8), out_dir=subdir, table="t_branch.csv", plot="branch.pdf") # `cos(π/8)` is due to octagonal approximation of apparent power in `_FP.BFARadPowerModel`
        sol_report_bus_voltage_magnitude(sol, d_data_sub; out_dir=subdir, table="t_bus.csv", plot="bus.pdf")
        sol_report_gen(sol, d_data_sub; out_dir=subdir, table="t_gen.csv", plot="gen.pdf")
        sol_report_load(sol, d_data_sub; out_dir=subdir, table="t_load.csv", plot="load.pdf")
        sol_report_load_summary(sol, d_data_sub; out_dir=subdir, table="t_load_summary.csv", plot="load_summary.pdf")
        sol_report_investment_summary(sol, d_data_sub; out_dir=subdir, table="t_investment_summary.csv", plot="investment_summary.pdf")
        sol_report_storage(sol, d_data_sub; out_dir=subdir, table="t_storage.csv", plot="storage.pdf")
        sol_report_storage_summary(sol, d_data_sub; out_dir=subdir, table="t_storage_summary.csv", plot="storage_summary.pdf")
        sol_graph(sol, d_data_sub; plot="map.pdf", out_dir=subdir, hour=1) # Just as an example; dimension coordinates can also be vectors, or be omitted, in which case one plot for each coordinate will be generated.
    end
end


## Compare with combined T&D model

if compare_with_combined_td_model
    info(_LOGGER, "Solving planning problem using combined T&D model...")
    result_combined = _FP.run_model(
        t_data, d_data, t_model_type, d_model_type, optimizer, build_method;
        t_ref_extensions, d_ref_extensions, t_solution_processors, d_solution_processors, t_setting, d_setting, direct_model
    )
    info(_LOGGER, "Solution of combined T&D model took $(round(result_combined["solve_time"]; sigdigits=3)) seconds")
    obj_combined = result_combined["objective"]
    obj_decoupling = result_decoupling["objective"]
    diff = obj_decoupling - obj_combined
    ratio = obj_decoupling / obj_combined
    digits = max(1, ceil(Int,-log10(abs(diff)))+1)
    info(_LOGGER, "Combined T&D model objective: $(round(obj_combined; digits))")
    info(_LOGGER, "    T&D decoupling objective: $(round(obj_decoupling; digits)) ($(round((ratio-1)*100; sigdigits=3))% higher)")
    if diff < 0
        warn(_LOGGER, "T&D decoupling objective is less than that of combined T&D model. This should not happen!")
    end
end

notice(_LOGGER, "Test completed in $(round(time()-time_start;sigdigits=3)) seconds. Results saved in $out_dir")
