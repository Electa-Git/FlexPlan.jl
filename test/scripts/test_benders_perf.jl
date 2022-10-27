# Test of Benders decomposition performance

import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
using Memento
using Printf
_LOGGER = Logger(basename(@__FILE__)[1:end-3]) # A logger for this script, also used by included files.
include("../io/load_case.jl")
include("../benders/perf.jl")
include("../benders/cplex.jl")
include("../benders/plots.jl")


## Settings

settings = Dict(
    :session => Dict{Symbol,Any}(
        :out_dir => "test/data/output_files/benders/perf",
        :repetitions => 3, # How many times to run each optimization
    ),
    :case => Dict{Symbol, Any}(
        :cost_scale_factor => 1e-6, # Cost scale factor (to test the numerical tractability of the problem)
    ),
    :optimization => Dict{Symbol,Any}(
        :obj_rtol => 1e-4, # Relative tolerance for stopping
        :max_iter => 10000, # Iteration limit
        :tightening_rtol => 1e-9, # Relative tolerance for adding optimality cuts
        :silent => true, # Suppress solvers output, taking precedence over any other solver attribute
    )
)


## Set up paths and logging

settings[:session][:tasks_dir] = mkpath(joinpath(settings[:session][:out_dir],"tasks"))
settings[:session][:results_dir] = mkpath(joinpath(settings[:session][:out_dir],"results"))
datetime_format = "yyyymmddTHHMMSS\\Z" # As per ISO 8601. Basic format (i.e. without separators) is used for consistency across operating systems.
setlevel!.(Memento.getpath(getlogger(_FP)), "debug") # Log messages from FlexPlan having level >= "debug"
root_logger = getlogger()
push!(gethandlers(root_logger)["console"], Memento.Filter(rec -> rec.name==_LOGGER.name || root_logger.levels[getlevel(rec)]>=root_logger.levels["warn"])) # Filter console output: display all records from this script and records from other loggers having level >= "warn"
script_start_time = now(UTC)
main_log_file = joinpath(settings[:session][:out_dir],basename(@__FILE__)[1:end-3]*"-$(Dates.format(script_start_time,datetime_format)).log")
rm(main_log_file; force=true)
function switch_log_file(new_log_file::String)
    filter!(handler -> first(handler)=="console", gethandlers(root_logger)) # Remove from root logger possible previously added handlers
    push!(getlogger(), DefaultHandler(new_log_file)) # Tell root logger to write to our log file as well
end
switch_log_file(main_log_file)

notice(_LOGGER, "Performance tests for Benders decomposition started.")
info(_LOGGER, "Script start time: $script_start_time (UTC)")
info(_LOGGER, "Available threads: $(Threads.nthreads())")


## Set up tests

notice(_LOGGER, "Setting up tests...")

params = Dict(
    :case => [:test_case=>String, :number_of_hours=>Int, :number_of_scenarios=>Int, :number_of_years=>Int],
    :optimization => [
        :algorithm => String, # Possible values: `benchmark`, `cplex_auto`, `manual_classical`, `manual_modern`
        :preprocessing_repeatpresolve => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_search => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :emphasis_mip => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_nodeselect => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_variableselect => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_bbinterval => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_branch => Int, # Only used by `manual_classical` and `manual_modern` algorithms
        :mip_strategy_probe => Int, # Only used by `manual_classical` and `manual_modern` algorithms
    ]
)
tasks = initialize_tasks(params)

# Toy job, just to run the script and see some results
add_tasks!(tasks; test_case="case6", number_of_hours=[2,4], number_of_scenarios=4, number_of_years=3,
    algorithm = ["manual_classical","manual_modern"],
    preprocessing_repeatpresolve = -1,
    mip_strategy_search = 2,
    emphasis_mip = 1,
    mip_strategy_nodeselect = 3,
    mip_strategy_variableselect = 0,
    mip_strategy_bbinterval = 7,
    mip_strategy_branch = 1,
    mip_strategy_probe = 0,
)

# Example: test how performance changes by varying one or more optimization parameters
#add_tasks!(tasks; test_case="case67", number_of_hours=[2,4], number_of_scenarios=3, number_of_years=3,
#    algorithm = "manual_modern",
#    preprocessing_repeatpresolve = -1,
#    mip_strategy_search = 2,
#    emphasis_mip = 1,
#    mip_strategy_nodeselect = 3,
#    mip_strategy_variableselect = 0,
#    mip_strategy_bbinterval = 7,
#    mip_strategy_branch = [0,1],
#    mip_strategy_probe = 0,
#)


## Warm up

notice(_LOGGER, "Warming up...")
warmup_tasks = similar(tasks, 0)
add_tasks!(warmup_tasks; test_case="case6", number_of_hours=1, number_of_scenarios=1, number_of_years=1, algorithm=unique(tasks.algorithm), preprocessing_repeatpresolve=-1, mip_strategy_search=2, emphasis_mip=1, mip_strategy_nodeselect=3, mip_strategy_variableselect=0, mip_strategy_bbinterval=7, mip_strategy_branch=1, mip_strategy_probe=0)
warmup_dir = joinpath(settings[:session][:out_dir], "warmup")
rm(warmup_dir; force=true, recursive=true)
mkpath(warmup_dir)
warmup_settings = Dict(
    :case => settings[:case],
    :optimization => settings[:optimization],
    :session => Dict{Symbol, Any}(
        :out_dir => warmup_dir,
        :tasks_dir => mkpath(joinpath(warmup_dir,"tasks")),
        :results_dir => mkpath(joinpath(warmup_dir,"results")),
        :repetitions => 1
    )
)
run_performance_tests(warmup_tasks, params, warmup_settings; use_existing_results=false)


## Run tests

notice(_LOGGER, "Running tests...")
results = run_performance_tests(tasks, params, settings; use_existing_results=true)


## Analyze results

notice(_LOGGER, "Analyzing results...")
make_benders_perf_plots(results, settings[:session][:results_dir])
notice(_LOGGER, "Performance tests for Benders decomposition ended.")


## Analyze results of a previous run

#make_benders_perf_plots("test/data/output_files/benders/my_old_perf_run/results")
