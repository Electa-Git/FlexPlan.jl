# Test of Benders' decomposition


## Import packages

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
using DataFrames
using Memento
using Plots
using Printf
# Solvers are imported later


## Input parameters

# Test case to run
test_case = "cigre" # Available test cases (see below): "case2", "case6", "cigre"

# Number of hourly optimization periods
number_of_hours = 24

# Cost scale factor (to test the numerical tractability of the problem)
scale_cost = 1e0

# Logger verbosity level
setlevel!.(Memento.getpath(getlogger("FlexPlan")), "debug") # Useful values: "info", "debug", "trace"

# Suppress solvers output, taking precedence over any other solver attribute (effective only in Benders' decomposition)
silent = true

# Output directory
out_dir = "test/data/output_files"

# Solvers
use_opensource_solvers = true # More options below


## Import and set solvers

if use_opensource_solvers
    import Cbc
    optimizer_MILP = _FP.optimizer_with_attributes(Cbc.Optimizer,
        "logLevel" => 0, # ∈ {0,1}, default: 0
    ) # Solver options: <https://github.com/jump-dev/Cbc.jl#using-with-jump>
    import Clp
    optimizer_LP = _FP.optimizer_with_attributes(Clp.Optimizer,
        "LogLevel" => 0, # ∈ {0,...,4}, default: 1
        "SolveType" => 5, # dual simplex: 0, primal simplex: 1, sprint: 2, barrier with crossover: 3, barrier without crossover: 4, automatic: 5; default: 5
    ) # Solver options: <https://github.com/jump-dev/Clp.jl#solver-options>
    optimizer_benchmark = optimizer_MILP
else
    import CPLEX
    function CPLEX_optimizer_with_logger(log_name::String) # Return a function
        function CPLEX_opt_w_log() # Like CPLEX.Optimizer, but dumps to the specified log file
            model = CPLEX.Optimizer()
            CPLEX.CPXsetlogfilename(model.env, normpath(out_dir,"$log_name.log"), "w+")
            return model
        end
    end
    optimizer_MILP = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("milp"),
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_MIP_Display" => 2, # ∈ {0,...,5}, default: 2
    ) # Solver options: <https://www.ibm.com/docs/en/icos/20.1.0?topic=cplex-list-parameters>
    optimizer_LP = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("lp"),
        "CPXPARAM_LPMethod" => 0, # ∈ {0,...,6}, default: 0, <https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-algorithm-continuous-linear-problems>
        "CPXPARAM_Simplex_Tolerances_Feasibility" => 1e-6, # ∈ [1e-9,1e-1], default: 1e-6
        "CPXPARAM_Read_Scale" => 1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_Simplex_Display" => 1, # ∈ {0,1,2}, default: 1
        "CPXPARAM_Barrier_Display" => 1, # ∈ {0,1,2}, default: 1
    ) # Solver options: <https://www.ibm.com/docs/en/icos/20.1.0?topic=cplex-list-parameters>
    optimizer_benchmark = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("benchmark"),
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_MIP_Display" => 2, # ∈ {0,...,5}, default: 2
    ) # Solver options: <https://www.ibm.com/docs/en/icos/20.1.0?topic=cplex-list-parameters>
end


## Test case preparation

if test_case == "case2" # Single-period toy model

    file = "./test/data/case2.m" # Input case

    model_type = _FP.BFARadPowerModel
    data = _FP.parse_file(file)

elseif test_case == "case6" # Multiperiod 6-bus transmission network

    file = "./test/data/combined_td_model/t_case6.m"

    model_type = _PM.DCPPowerModel
    scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["year"] = 2019
    scenario["sc_years"]["1"]["start"] = 1546300800000 # 2019-01-01T00:00:00.000 in epoch time
    scenario["sc_years"]["1"]["probability"] = 1
    scenario["planning_horizon"] = 1
    data = _FP.parse_file(file, scenario; scale_cost)
    data, loadprofile, genprofile = _FP.create_profile_data_italy(data, scenario)
    extradata = _FP.create_profile_data(scenario["hours"]*length(data["scenario"]), data, loadprofile, genprofile)
    data = _FP.multinetwork_data(data, extradata)

elseif test_case == "cigre" # Multiperiod 15-bus distribution network

    file = "test/data/combined_td_model/d_cigre.m"
    scale_load = 3.0 # Scaling factor of loads
    scale_gen  = 1.0 # Scaling factor of generators

    model_type = _FP.BFARadPowerModel
    scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["year"] = 2019
    scenario["sc_years"]["1"]["start"] = 1546300800000 # 2019-01-01T00:00:00.000 in epoch time
    scenario["sc_years"]["1"]["probability"] = 1
    scenario["planning_horizon"] = 1
    data = _FP.parse_file(file, scenario; scale_cost)
    extradata = _FP.create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen)
    data = _FP.multinetwork_data(data, extradata)

end


## Process script parameters

optimizer_MILP_name = string(optimizer_MILP.optimizer_constructor)[1:end-10]
optimizer_LP_name = string(optimizer_LP.optimizer_constructor)[1:end-10]
param_string = @sprintf("%s_%04i_%s_%s_%.0e", test_case, number_of_hours, optimizer_MILP_name, optimizer_LP_name, scale_cost)
out_dir = normpath(out_dir, "benders_" * param_string)
mkpath(out_dir)
main_log_file = joinpath(out_dir,"decomposition.log")
rm(main_log_file, force = true)
empty!(getlogger("FlexPlan").handlers) # Prevents writing to previously pushed files
push!(getlogger("FlexPlan"), DefaultHandler(main_log_file))


## Solve problem

println("Solving the problem with Benders' decomposition...")
result_benders = _FP.run_benders_decomposition(
    data, model_type,
    optimizer_MILP, optimizer_LP,
    _FP.post_flex_tnep_benders_main, _FP.post_flex_tnep_benders_secondary;
    ref_extensions = model_type == _PM.DCPPowerModel
        ? [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, _FP.add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!]
        : [_PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!, _FP.add_candidate_storage!],
    solution_processors = [_PM.sol_data_model!],
    setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false),
    silent
)

println("Solving the problem as MILP...")
result_benchmark = _FP.flex_tnep(data, model_type, optimizer_benchmark; multinetwork=_PM._IM.ismultinetwork(data), setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false))
@assert result_benchmark["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
@printf("MILP time: %.1f s.\n", result_benchmark["solve_time"])

@printf("Benders/MILP solve time ratio: %.2f.\n", result_benders["solve_time"]/result_benchmark["solve_time"])


## Analyze result

stat = result_benders["stat"]
n_iter = length(stat) # iterations
ub = [stat[i]["ub"] for i in 1:n_iter]
lb = [stat[i]["lb"] for i in 1:n_iter]
sol = [stat[i]["sol_value"] for i in 1:n_iter]
sol_nonimproving = [stat[i]["current_best"] ? NaN : sol[i] for i in 1:n_iter]
sol_improving = [stat[i]["current_best"] ? sol[i] : NaN for i in 1:n_iter]
opt = result_benchmark["objective"]

# Plots: solution value versus iterations

plt = plot(1:n_iter, [ub, lb, sol_improving, sol_nonimproving];
    label      = ["UB" "LB" "improving solution" "non-improving solution"],
    seriestype = [:step :step :scatter :scatter],
    color      = [3 2 1 HSL(0,0,0.5)],
    ylims      = [lb[ceil(Int,n_iter/5)], max(sol[ceil(Int,n_iter/5):n_iter]...)],
    title      = "Benders' decomposition solutions",
    ylabel     = "Cost",
    xlabel     = "Iterations",
    legend     = :bottomleft,
)
savefig(plt, normpath(out_dir,"sol_lin.svg"))
display(plt)

plt = plot!(plt; yscale = :log10, ylims = [0.1opt, Inf])
savefig(plt, normpath(out_dir,"sol_log10.svg"))
display(plt)

# Plot: binary variable values versus iterations

comp_names = Dict{String,String}(
    "ne_branch"   => "AC branch",
    "branchdc_ne" => "DC branch",
    "convdc_ne"   => "converter",
    "ne_storage"  => "storage",
    "load"        => "flex load"
)
comp_built = Dict{String,String}(
    "ne_branch"   => "built",
    "branchdc_ne" => "isbuilt",
    "convdc_ne"   => "isbuilt",
    "ne_storage"  => "isbuilt",
    "load"        => "isflex"
)
int_vars = DataFrame(comp = String[], name = String[], idx=Int[], legend = String[], values = Vector{Bool}[])
main_sol = haskey(result_benders["solution"],"multinetwork") && result_benders["solution"]["multinetwork"] ? [stat[i]["main_sol"]["nw"]["1"] for i in 1:n_iter] : [stat[i]["main_sol"] for i in 1:n_iter]
for (comp, name) in comp_names
    if haskey(main_sol[1], comp)
        for idx in keys(main_sol[1][comp])
            push!(int_vars, (comp, name, parse(Int,idx), "$name $idx", [round(Int,main_sol[i][comp][idx][comp_built[comp]]) for i in 1:n_iter]))
        end
    end
end
sort!(int_vars, (:name, :idx))
select!(int_vars, :legend, :values)
values_matrix = Array{Int}(undef, nrow(int_vars), n_iter)
for n in 1:nrow(int_vars)
    values_matrix[n,:] = int_vars.values[n]
end
values_matrix_plot = values_matrix + repeat(2isfinite.(sol_improving)', nrow(int_vars))
# | value | color      | component built? | improving iteration? |
# | ----- | ---------- | ---------------- | -------------------- |
# |     0 | light grey |        no        |          no          |
# |     1 | dark grey  |       yes        |          no          |
# |     2 | light blue |        no        |         yes          |
# |     3 | dark blue  |       yes        |         yes          |
plt = heatmap(1:n_iter, int_vars.legend, values_matrix_plot;
    yflip    = true,
    yticks   = :all,
    title    = "Investment decisions",
    ylabel   = "Components",
    xlabel   = "Iterations",
    color    = ColorGradient([HSL(0,0,0.75), HSL(0,0,0.5), HSL(203,0.5,0.76), HSL(203,0.5,0.51)], [0.0, 1//3, 2//3, 1.0]),
    colorbar = :none,
)
savefig(plt, normpath(out_dir,"intvars.svg"))
display(plt)

println("Output files saved in \"$out_dir\".")
println("Test completed.")