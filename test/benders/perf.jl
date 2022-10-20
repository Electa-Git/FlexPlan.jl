# Functions to make performance tests of decomposition implementations

using CSV
using DataFrames
using Dates

function initialize_tasks(params::Dict)
    DataFrame([name=>type[] for (name,type) in [params[:case]; params[:optimization]]])
end

function add_tasks!(tasks::DataFrame; kwargs...)
    names = keys(kwargs)
    mismatched_names = symdiff(Set(propertynames(tasks)),Set(names))
    if !isempty(mismatched_names)
        Memento.error(_LOGGER, "The parameters of the tasks to be added do not match the defined parameters. Check \"" * join(string.(mismatched_names), "\", \"", "\" and \"") * "\".")
    end
    vals = [v isa Vector ? v : [v] for v in values(kwargs)]
    for job_values in Iterators.product(vals...)
        push!(tasks, Dict(Pair.(names, job_values)))
    end
    return unique!(tasks)
end

function load_case(case, case_settings)
    data, model_type, ref_extensions, solution_processors, setting = eval(Symbol("load_$(case[:test_case])_defaultparams"))(; number_of_hours=case[:number_of_hours], number_of_scenarios=case[:number_of_scenarios], number_of_years=case[:number_of_years], case_settings...)
    return Dict(:data=>data, :model_type=>model_type, :ref_extensions=>ref_extensions, :solution_processors=>solution_processors, :setting=>setting)
end

function run_and_time(
        data::Dict{String,<:Any},
        model_type::Type,
        optimizer::Union{_FP._MOI.AbstractOptimizer, _FP._MOI.OptimizerWithAttributes},
        build_method::Function;
        kwargs...
    )

    time_start = time()
    result = build_method(data, model_type, optimizer; kwargs...)
    @assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
    result["time"] = Dict{String,Any}("total" => time()-time_start)
    return result
end

function optimize_case(case_data, task, settings)
    opt_s = settings[:optimization]
    if task[:algorithm] ∈ ("manual_classical", "manual_modern")
        optimizer_MILP = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_s[:out_dir],"milp.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                                                    # range     default  link
            "CPXPARAM_Preprocessing_RepeatPresolve" => get(task,:preprocessing_repeatpresolve,-1),  # {-1,..., 3}    -1  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-repeat-presolve-switch>
            "CPXPARAM_MIP_Strategy_Search" => get(task,:mip_strategy_search,0),                     # { 0,..., 2}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-dynamic-search-switch>
            "CPXPARAM_Emphasis_MIP" => get(task,:emphasis_mip,0),                                   # { 0,..., 5}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-emphasis-switch>
            "CPXPARAM_MIP_Strategy_NodeSelect" => get(task,:mip_strategy_nodeselect,1),             # { 0,..., 3}     1  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-selection-strategy>
            "CPXPARAM_MIP_Strategy_VariableSelect" => get(task,:mip_strategy_variableselect,0),     # {-1,..., 4}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-variable-selection-strategy>
            "CPXPARAM_MIP_Strategy_BBInterval" => get(task,:mip_strategy_bbinterval,7),             # { 0, 1,...}     7  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-strategy-best-bound-interval>
            "CPXPARAM_MIP_Strategy_Branch" => get(task,:mip_strategy_branch,0),                     # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-branching-direction>
            "CPXPARAM_MIP_Strategy_Probe" => get(task,:mip_strategy_probe,0),                       # {-1,..., 3}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-probing-level>
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_s[:obj_rtol],                                   # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                                                           # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                                                            # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                                                       # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        optimizer_LP = _FP.optimizer_with_attributes(CPLEX.Optimizer, # Log file would be interleaved in case of multiple secondary problems. To enable logging, substitute `CPLEX.Optimizer` with: `CPLEX_optimizer_with_logger(<path_to_log_file>)`
                                            # range     default  link
            "CPXPARAM_Read_Scale" => 0,     # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_LPMethod" => 2,       # { 0,..., 6}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-algorithm-continuous-linear-problems>
            "CPXPARAM_ScreenOutput" => 0,   # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,    # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
        )
        if task[:algorithm] == "manual_classical"
            algo = _FP.Benders.Classical(; obj_rtol=opt_s[:obj_rtol], max_iter=opt_s[:max_iter], tightening_rtol=opt_s[:tightening_rtol], silent=opt_s[:silent])
        else
            algo = _FP.Benders.Modern(; max_iter=opt_s[:max_iter], tightening_rtol=opt_s[:tightening_rtol], silent=opt_s[:silent])
        end
        result = _FP.run_benders_decomposition(
            algo,
            case_data[:data], case_data[:model_type],
            optimizer_MILP, optimizer_LP,
            _FP.build_simple_stoch_flex_tnep_benders_main,
            _FP.build_simple_stoch_flex_tnep_benders_secondary;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
        make_benders_plots(case_data[:data], result, opt_s[:out_dir]; display_plots=false)
    elseif task[:algorithm] == "cplex_auto"
        optimizer_cplex = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_s[:out_dir],"cplex.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                    # range     default  link
            "CPXPARAM_Read_Scale" => 0,                             # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_s[:obj_rtol],   # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_Benders_Strategy" => 3,                       # {-1,..., 3}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-strategy>
            "CPXPARAM_Benders_WorkerAlgorithm" => 2,                # { 0,..., 5}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-worker-algorithm>
            "CPXPARAM_Benders_Tolerances_OptimalityCut" => 1e-6,    # [1e-9,1e-1]  1e-6  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-optimality-cut-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                           # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                            # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                       # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        result = run_and_time(
            case_data[:data], case_data[:model_type],
            optimizer_cplex,
            _FP.simple_stoch_flex_tnep;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
    elseif task[:algorithm] == "benchmark"
        optimizer_benchmark = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_s[:out_dir],"benchmark.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                    # range     default  link
            "CPXPARAM_Read_Scale" => 0,                             # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_s[:obj_rtol],   # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                           # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                            # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                       # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        result = run_and_time(
            case_data[:data], case_data[:model_type],
            optimizer_benchmark,
            _FP.simple_stoch_flex_tnep;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
    else
        Memento.error(_LOGGER, "Algorithm \"$(task[:algorithm])\" not implemented.")
    end
    return result["termination_status"], result["time"]["total"]
end

function initialize_results(results_file::String, tasks::DataFrame)
    results = similar(tasks, 0)
    results[!, :task_start_time] = DateTime[]
    results[!, :termination_status] = String[]
    results[!, :time] = Float64[]
    CSV.write(results_file, results)
    return results
end

function run_performance_tests(tasks::DataFrame, params::Dict, settings::Dict; use_existing_results::Bool=true)
    results_file = joinpath(settings[:session][:results_dir],"results.csv")
    if use_existing_results && isfile(results_file)
        results = CSV.read(results_file, DataFrame; pool=false, stringtype=String)
        if setdiff(propertynames(results), [:task_start_time, :termination_status, :time]) != propertynames(tasks)
            Memento.error(_LOGGER, "Results file \"$results_file\" has different fields than expected. Please remove it manually or adjust params to match.")
        end
        if nrow(results) == 0 # Since there is no data, CSV.read could not infer the column types. Overwrite the file.
            results = initialize_results(results_file, tasks)
        end
    else
        results = initialize_results(results_file, tasks)
    end
    n_tasks = nrow(tasks) * settings[:session][:repetitions]
    n_curr_task = 0
    tasks_by_case = groupby(tasks, [name for (name,type) in params[:case]]; sort=false)
    for case in keys(tasks_by_case)
        case_string = join(["$val" for val in case], "_")
        info(_LOGGER, "Loading case $case_string...")
        mkpath(joinpath(settings[:session][:tasks_dir], case_string))
        case_log_file = joinpath(settings[:session][:tasks_dir], case_string, "load_$case_string.log")
        rm(case_log_file; force=true)
        switch_log_file(case_log_file)
        case_data = load_case(case, settings[:case])
        switch_log_file(main_log_file)
        for task in eachrow(tasks_by_case[case])
            existing_tasks_like_this = use_existing_results ? nrow(filter(row -> row[1:ncol(tasks)]==task, results)) : 0
            for r in 1:settings[:session][:repetitions]
                task_start_time = now(UTC)
                n_curr_task += 1
                optimization_string = join(["$(task[name])" for (name,type) in params[:optimization]], "_")
                info(_LOGGER, "┌ $n_curr_task/$n_tasks: $case_string-$optimization_string ($r/$(settings[:session][:repetitions]))")
                info(_LOGGER, "│ started at $(task_start_time)Z")
                if r > existing_tasks_like_this
                    task_dir = settings[:optimization][:out_dir] = mkpath(joinpath(settings[:session][:tasks_dir], case_string, optimization_string, Dates.format(task_start_time,datetime_format)))
                    switch_log_file(joinpath(task_dir, "algorithm.log"))
                    termination_status, task_duration = optimize_case(case_data, task, settings)
                    if termination_status != _PM.OPTIMAL
                        Memento.warn(_LOGGER, "$case_string-$optimization_string: termination status is $(termination_status)")
                    end
                    switch_log_file(main_log_file)
                    push!(results, (task..., task_start_time, "$termination_status", task_duration))
                    CSV.write(results_file, DataFrame(last(results)); append=true)
                    info(_LOGGER, "└ completed in $(round(Int,task_duration)) s")
                else
                    info(_LOGGER, "└ skipped (reusing existing result)")
                end
            end
        end
    end
    return results
end
