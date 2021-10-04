# Test of Benders decomposition


## Import packages and load common code

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
using Dates
using Memento
using Printf
include("../benders/test_case.jl")
include("../benders/compare.jl")
include("../benders/plots.jl")
# Solvers are imported later


## Input parameters

# Test case
# | Case        |     Type     | Buses | Hours | Scenarios | Years |
# | ----------- | :----------: | ----: | ----: | --------: | ----: |
# | `case6`     | transmission |     6 |  8760 |        35 |     3 |
# | `case67`    | transmission |    67 |  8760 |         3 |     3 |
# | `cigre`     | distribution |    15 |    24 |         1 |     1 |
# | `cigre_ext` | distribution |    15 |  8760 |         1 |     1 |
# | `case2`     | distribution |     2 |     1 |         1 |     1 |
test_case = "case6"
number_of_hours = 8 # Number of hourly optimization periods
number_of_scenarios = 4 # Number of scenarios (different generation/load profiles)
number_of_years = 3 # Number of years (different investments)
scale_cost = 1e-9 # Cost scale factor (to test the numerical tractability of the problem)

# Procedure
algorithm = _FP.Benders.Modern # `_FP.Benders.Classical` or `_FP.Benders.Modern`
obj_rtol = 1e-6 # Relative tolerance for stopping
max_iter = 1000 # Iteration limit
tightening_rtol = 1e-9 # Relative tolerance for adding optimality cuts
silent = true # Suppress solvers output, taking precedence over any other solver attribute

# Solvers
use_opensource_solvers = false # More options below

# Analysis and output
out_dir = "test/data/output_files"
make_plots = true # Make the following plots: solution value vs. iterations, decision variables vs. iterations, iteration times
display_plots = true
compare_to_benchmark = true # Solve the problem as MILP, check whether solutions are identical and compare solve times


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
        "CPXPARAM_MIP_Tolerances_MIPGap" => obj_rtol, # ∈ [0,1], default: 1e-4
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_MIP_Display" => 2, # ∈ {0,...,5}, default: 2
    ) # Solver options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
    optimizer_LP = _FP.optimizer_with_attributes(CPLEX.Optimizer, # Log file would be interleaved in case of multiple secondary problems. To enable logging, substitute `CPLEX.Optimizer` with: `CPLEX_optimizer_with_logger("lp")`
        "CPXPARAM_LPMethod" => 2, # ∈ {0,...,6}, default: 0, <https://www.ibm.com/docs/en/icos/latest?topic=parameters-algorithm-continuous-linear-problems>
        "CPXPARAM_Simplex_Tolerances_Feasibility" => 1e-6, # ∈ [1e-9,1e-1], default: 1e-6
        "CPXPARAM_Read_Scale" => 1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_Simplex_Display" => 1, # ∈ {0,1,2}, default: 1
        "CPXPARAM_Barrier_Display" => 1, # ∈ {0,1,2}, default: 1
    ) # Solver options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
    optimizer_benchmark = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("benchmark"),
        "CPXPARAM_MIP_Tolerances_MIPGap" => obj_rtol, # ∈ [0,1], default: 1e-4
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_MIP_Display" => 2, # ∈ {0,...,5}, default: 2
    ) # Solver options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
end


## Process script parameters, set up logging

algorithm_name = last(split(string(algorithm),'.'))
optimizer_MILP_name = string(optimizer_MILP.optimizer_constructor)[1:end-10]
optimizer_LP_name = string(optimizer_LP.optimizer_constructor)[1:end-10]
param_string = @sprintf("%s_%04i_%02i_%1i_%s_%s_%s_%.0e", test_case, number_of_hours, number_of_scenarios, number_of_years, algorithm_name, optimizer_MILP_name, optimizer_LP_name, scale_cost)
out_dir = normpath(out_dir, "benders_" * param_string)
mkpath(out_dir)
main_log_file = joinpath(out_dir,"decomposition.log")
rm(main_log_file, force = true)
filter!(handler -> first(handler)=="console", gethandlers(getlogger())) # Remove from root logger possible previously added handlers
push!(getlogger(), DefaultHandler(main_log_file)) # Tell root logger to write to our log file as well
setlevel!.(Memento.getpath(getlogger(FlexPlan)), "debug") # FlexPlan logger verbosity level. Useful values: "info", "debug", "trace"
script_logger = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script. Name is filename without `.jl` extension, level is "info" by default.
info(script_logger, "Script parameter string: \"$param_string\"")
info(script_logger, "Now is $(now(UTC)) (UTC)")


## Load test case

data, model_type, ref_extensions, solution_processors, setting = load_test_case(test_case; number_of_hours, number_of_scenarios, number_of_years, scale_cost)


## Solve problem

info(script_logger, "Solving the problem with Benders decomposition...")
algo = algorithm == _FP.Benders.Classical ? algorithm(; obj_rtol, max_iter, tightening_rtol, silent) : algorithm(; max_iter, tightening_rtol, silent)
result_benders = _FP.run_benders_decomposition(
    algo,
    data, model_type,
    optimizer_MILP, optimizer_LP,
    _FP.post_stoch_flex_tnep_benders_main,
    _FP.post_stoch_flex_tnep_benders_secondary;
    ref_extensions, solution_processors, setting
)


## Make plots

if make_plots
    info(script_logger, "Making plots...")
    make_benders_plots(result_benders, out_dir; display_plots)
end


## Solve benchmark and compare

if compare_to_benchmark
    info(script_logger, "Solving the problem as MILP...")
    result_benchmark = run_and_time(data, model_type, optimizer_benchmark, _FP.stoch_flex_tnep; ref_extensions, solution_processors, setting)
    info(script_logger, @sprintf("MILP time: %.1f s", result_benchmark["time"]["total"]))
    info(script_logger, @sprintf("Benders/MILP solve time ratio: %.3f", result_benders["time"]["total"]/result_benchmark["time"]["total"]))
    check_solution_correctness(result_benders, result_benchmark, obj_rtol, script_logger)
end


println("Output files saved in \"$out_dir\"")
info(script_logger, "Test completed")
