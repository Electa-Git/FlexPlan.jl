# Test of CPLEX Benders decomposition


## Import packages and load common code

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
using Dates
using Memento
using Printf
import CPLEX
include("../benders/test_case.jl")
include("../benders/compare.jl")
include("../benders/cplex.jl")


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
obj_rtol = 1e-6 # Relative tolerance for stopping

# Analysis and output
out_dir = "test/data/output_files"
compare_to_benchmark = true # Solve the problem as MILP, check whether solutions are identical and compare solve times


## Set CPLEX

function CPLEX_optimizer_with_logger(log_name::String) # Return a function
    function CPLEX_opt_w_log() # Like CPLEX.Optimizer, but dumps to the specified log file
        model = CPLEX.Optimizer()
        CPLEX.CPXsetlogfilename(model.env, normpath(out_dir,"$log_name.log"), "w+")
        return model
    end
end
optimizer_benders = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("benders"), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                         # range     default  link
    "CPXPARAM_Read_Scale" => 0,                          # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
    "CPXPARAM_MIP_Tolerances_MIPGap" => obj_rtol,        # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
    "CPXPARAM_Benders_Strategy" => 3,                    # {-1,..., 3}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-strategy>
    "CPXPARAM_Benders_WorkerAlgorithm" => 2,             # { 0,..., 5}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-worker-algorithm>
    "CPXPARAM_Benders_Tolerances_OptimalityCut" => 1e-6, # [1e-9,1e-1]  1e-6  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-optimality-cut-tolerance>
    "CPXPARAM_ScreenOutput" => 0,                        # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
    "CPXPARAM_MIP_Display" => 2,                         # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
    "CPXPARAM_Output_CloneLog" => -1,                    # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
)
optimizer_benchmark = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("benchmark"), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                         # range     default  link
    "CPXPARAM_Read_Scale" => 0,                          # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
    "CPXPARAM_MIP_Tolerances_MIPGap" => obj_rtol,        # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
    "CPXPARAM_ScreenOutput" => 0,                        # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
    "CPXPARAM_MIP_Display" => 2,                         # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
)


## Process script parameters, set up logging

test_case_string = @sprintf("%s_%04i_%02i_%1i_%.0e", test_case, number_of_hours, number_of_scenarios, number_of_years, scale_cost)
algorithm_string = @sprintf("cplex")
out_dir = normpath(out_dir, "benders", test_case_string, algorithm_string)
mkpath(out_dir)
main_log_file = joinpath(out_dir,"script.log")
rm(main_log_file, force = true)
filter!(handler -> first(handler)=="console", gethandlers(getlogger())) # Remove from root logger possible previously added handlers
push!(getlogger(), DefaultHandler(main_log_file)) # Tell root logger to write to our log file as well
setlevel!.(Memento.getpath(getlogger(FlexPlan)), "debug") # FlexPlan logger verbosity level. Useful values: "info", "debug", "trace"
script_logger = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script. Name is filename without `.jl` extension, level is "info" by default.
info(script_logger, "Test case string: \"$test_case_string\"")
info(script_logger, "Algorithm string: \"$algorithm_string\"")
info(script_logger, "          Now is: $(now(UTC)) (UTC)")


## Load test case

data, model_type, ref_extensions, solution_processors, setting = load_test_case(test_case; number_of_hours, number_of_scenarios, number_of_years, scale_cost)
push!(solution_processors, _FP.sol_pm!) # To access pm after the optimization has ended.


## Solve problem

info(script_logger, "Solving the problem with CPLEX Benders decomposition...")
result_benders = run_and_time(data, model_type, optimizer_benders, _FP.stoch_flex_tnep; ref_extensions, solution_processors, setting)
info(script_logger, @sprintf("CPLEX benders time: %.1f s", result_benders["time"]["total"]))


# Show how many subproblems there are in CPLEX Benders decomposition

annotation_file = joinpath(out_dir, "myprob.ann")
pm = result_benders["solution"]["pm"]
m = get_cplex_optimizer(pm)
CPLEX.CPXwritebendersannotation(m.env, m.lp, annotation_file)
num_subproblems = get_num_subproblems(annotation_file)
info(script_logger, "CPLEX Benders decomposition has $num_subproblems subproblems.")


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
