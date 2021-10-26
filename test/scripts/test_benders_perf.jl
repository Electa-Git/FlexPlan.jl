# Test of Benders decomposition performance

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
using Memento
using Printf
_LOGGER = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script, also used by included files.
include("../benders/perf.jl")
include("../benders/test_case.jl")
include("../benders/cplex.jl")
include("../benders/plots.jl")


## Input parameters

session_params = Dict{Symbol, Any}(
    :out_dir => "test/data/output_files/benders/perf",
    :repetitions => 3, # How many times to run each optimization
)
case_params = Dict{Symbol, Any}(
    :scale_cost => 1e-9, # Cost scale factor (to test the numerical tractability of the problem)
)
optimization_params = Dict{Symbol,Any}(
    :obj_rtol => 1e-6, # Relative tolerance for stopping
    :max_iter => 10000, # Iteration limit
    :tightening_rtol => 1e-9, # Relative tolerance for adding optimality cuts
    :silent => true, # Suppress solvers output, taking precedence over any other solver attribute
)


## Set up logging

datetime_format = "yyyymmddTHHMMSS\\Z" # As per ISO 8601. Basic format (i.e. without separators) is used for consistency across operating systems.
setlevel!.(Memento.getpath(getlogger(FlexPlan)), "debug") # Log messages from FlexPlan having level >= "debug"
root_logger = getlogger()
push!(gethandlers(root_logger)["console"], Memento.Filter(rec -> rec.name==_LOGGER.name || root_logger.levels[getlevel(rec)]>=root_logger.levels["warn"])) # Filter console output: display all records from this script and records from other loggers having level >= "warn"
mkpath(session_params[:out_dir])
script_start_time = now(UTC)
main_log_file = joinpath(session_params[:out_dir],basename(@__FILE__)[1:end-3]*"-$(Dates.format(script_start_time,datetime_format)).log")
rm(main_log_file; force=true)
function switch_log_file(new_log_file::String)
    filter!(handler -> first(handler)=="console", gethandlers(root_logger)) # Remove from root logger possible previously added handlers
    push!(getlogger(), DefaultHandler(new_log_file)) # Tell root logger to write to our log file as well
end
switch_log_file(main_log_file)
session_params[:tasks_dir] = mkpath(joinpath(session_params[:out_dir],"tasks"))
session_params[:results_dir] = mkpath(joinpath(session_params[:out_dir],"results"))

notice(_LOGGER, "Performance tests for Benders decomposition started.")
info(_LOGGER, "Script start time: $script_start_time (UTC)")
info(_LOGGER, "Available threads: $(Threads.nthreads())")


## Set up tests

notice(_LOGGER, "Setting up tests...")
tasks = DataFrame(test_case=String[], number_of_hours=Int[], number_of_scenarios=Int[], number_of_years=Int[], algorithm=String[])
all_algorithms = ["manual_classical","manual_modern","cplex_auto","benchmark"]

# Toy job
add_tasks!(tasks; test_case=["case6"], number_of_hours=[1,6], number_of_scenarios=[8], number_of_years=[1], algorithm=all_algorithms)
add_tasks!(tasks; test_case=["case6"], number_of_hours=[6], number_of_scenarios=[1,8], number_of_years=[1], algorithm=all_algorithms)

# Quick job
#add_tasks!(tasks; test_case=["case6"], number_of_hours=[1,6,24], number_of_scenarios=[32], number_of_years=[3], algorithm=all_algorithms)
#add_tasks!(tasks; test_case=["case6"], number_of_hours=[24], number_of_scenarios=[1,8,32], number_of_years=[3], algorithm=all_algorithms)

# Long job
#add_tasks!(tasks; test_case=["case67"], number_of_hours=[1,6,24], number_of_scenarios=[3], number_of_years=[3], algorithm=all_algorithms)
#add_tasks!(tasks; test_case=["case67"], number_of_hours=[24], number_of_scenarios=[1,3], number_of_years=[3], algorithm=all_algorithms)


## Warm up

notice(_LOGGER, "Warming up...")
warmup_tasks = similar(tasks, 0)
add_tasks!(warmup_tasks; test_case=["case6"], number_of_hours=[1], number_of_scenarios=[1], number_of_years=[1], algorithm=unique(tasks.algorithm))
warmup_dir = joinpath(session_params[:out_dir], "warmup")
rm(warmup_dir; force=true, recursive=true)
mkpath(warmup_dir)
optimization_params[:out_dir] = warmup_dir
warmup_params = Dict{Symbol, Any}(:out_dir=>warmup_dir, :tasks_dir=>mkpath(joinpath(warmup_dir,"tasks")), :results_dir=>mkpath(joinpath(warmup_dir,"results")), :repetitions=>1)
run_performance_tests(warmup_tasks, case_params, optimization_params, warmup_params; use_existing_results=false)


## Run tests

notice(_LOGGER, "Running tests...")
results = run_performance_tests(tasks, case_params, optimization_params, session_params; use_existing_results=true)


## Analyze results

notice(_LOGGER, "Analyzing results...")
make_benders_perf_plots(results, session_params[:results_dir])
notice(_LOGGER, "Performance tests for Benders decomposition ended.")


## Analyze results of a previous run

#make_benders_perf_plots("test/data/output_files/benders/my_old_perf_run/results")
