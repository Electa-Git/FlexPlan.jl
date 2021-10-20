# Functions to make performance tests of decomposition implementations

using CSV
using DataFrames
using Dates

function add_tasks!(tasks::DataFrame; kwargs...)
    fields = keys(kwargs)
    for job_values in Iterators.product(values(kwargs)...)
        push!(tasks, Dict(Pair.(fields, job_values)))
    end
    return unique!(tasks)
end

function load_case(case, case_params)
    data, model_type, ref_extensions, solution_processors, setting = load_test_case(case[:test_case]; number_of_hours=case[:number_of_hours], number_of_scenarios=case[:number_of_scenarios], number_of_years=case[:number_of_years], case_params...)
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

function optimize_case(case_data, task, opt_params)
    if task[:algorithm] ∈ ("manual_classical", "manual_modern")
        optimizer_MILP = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_params[:out_dir],"milp.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                       # range     default  link
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_params[:obj_rtol], # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                              # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                               # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                          # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        optimizer_LP = _FP.optimizer_with_attributes(CPLEX.Optimizer, # Log file would be interleaved in case of multiple secondary problems. To enable logging, substitute `CPLEX.Optimizer` with: `CPLEX_optimizer_with_logger("lp")`
                                                                       # range     default  link
            "CPXPARAM_Read_Scale" => 0,                                # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_LPMethod" => 2,                                  # { 0,..., 6}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-algorithm-continuous-linear-problems>
            "CPXPARAM_ScreenOutput" => 0,                              # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                               # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
        )
        if task[:algorithm] == "manual_classical"
            algo = _FP.Benders.Classical(; obj_rtol=opt_params[:obj_rtol], max_iter=opt_params[:max_iter], tightening_rtol=opt_params[:tightening_rtol], silent=opt_params[:silent])
        else
            algo = _FP.Benders.Modern(; max_iter=opt_params[:max_iter], tightening_rtol=opt_params[:tightening_rtol], silent=opt_params[:silent])
        end
        result = _FP.run_benders_decomposition(
            algo,
            case_data[:data], case_data[:model_type],
            optimizer_MILP, optimizer_LP,
            _FP.post_stoch_flex_tnep_benders_main,
            _FP.post_stoch_flex_tnep_benders_secondary;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
        make_benders_plots(case_data[:data], result, opt_params[:out_dir]; display_plots=false)
    elseif task[:algorithm] == "cplex_auto"
        optimizer_cplex = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_params[:out_dir],"cplex.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                       # range     default  link
            "CPXPARAM_Read_Scale" => 0,                                # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_params[:obj_rtol], # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_Benders_Strategy" => 3,                          # {-1,..., 3}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-strategy>
            "CPXPARAM_Benders_WorkerAlgorithm" => 2,                   # { 0,..., 5}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-worker-algorithm>
            "CPXPARAM_Benders_Tolerances_OptimalityCut" => 1e-6,       # [1e-9,1e-1]  1e-6  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-benders-optimality-cut-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                              # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                               # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                          # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        result = run_and_time(
            case_data[:data], case_data[:model_type],
            optimizer_cplex,
            _FP.stoch_flex_tnep;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
    elseif task[:algorithm] == "benchmark"
        optimizer_benchmark = _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger(normpath(opt_params[:out_dir],"benchmark.log")), # Options: <https://www.ibm.com/docs/en/icos/latest?topic=cplex-list-parameters>
                                                                       # range     default  link
            "CPXPARAM_Read_Scale" => 0,                                # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-scale-parameter>
            "CPXPARAM_MIP_Tolerances_MIPGap" => opt_params[:obj_rtol], # [ 0,     1]  1e-4  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-relative-mip-gap-tolerance>
            "CPXPARAM_ScreenOutput" => 0,                              # { 0,     1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-messages-screen-switch>
            "CPXPARAM_MIP_Display" => 2,                               # { 0,..., 5}     2  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-mip-node-log-display-information>
            "CPXPARAM_Output_CloneLog" => -1,                          # {-1,..., 1}     0  <https://www.ibm.com/docs/en/icos/latest?topic=parameters-clone-log-in-parallel-optimization>
        )
        result = run_and_time(
            case_data[:data], case_data[:model_type],
            optimizer_benchmark,
            _FP.stoch_flex_tnep;
            ref_extensions=case_data[:ref_extensions], solution_processors=case_data[:solution_processors], setting=case_data[:setting]
        )
    else
        error("Algorithm not implemented.")
    end
    return result["termination_status"], result["time"]["total"]
end

function run_performance_tests(tasks::DataFrame, case_params::Dict, opt_params::Dict, session_params::Dict; use_existing_results::Bool=true)
    results_file = joinpath(session_params[:results_dir],"results.csv")
    if use_existing_results && isfile(results_file)
        results = CSV.read(results_file, DataFrame; pool=false, stringtype=String)
    else
        results = similar(tasks, 0)
        results[!, :task_start_time] = DateTime[]
        results[!, :termination_status] = String[]
        results[!, :time] = Float64[]
    end
    n_tasks = nrow(tasks) * session_params[:repetitions]
    n_curr_task = 0
    tasks_by_case = groupby(tasks, Not(:algorithm); sort=false)
    for case in keys(tasks_by_case)
        case_string = @sprintf("%s_%04i_%02i_%1i", case[:test_case], case[:number_of_hours], case[:number_of_scenarios], case[:number_of_years])
        info(_LOGGER, "Loading case $case_string...")
        mkpath(joinpath(session_params[:tasks_dir], case_string))
        case_log_file = joinpath(session_params[:tasks_dir], case_string, "load_$case_string.log")
        rm(case_log_file; force=true)
        switch_log_file(case_log_file)
        case_data = load_case(case, case_params)
        switch_log_file(main_log_file)
        for task in eachrow(tasks_by_case[case])
            existing_tasks_like_this = use_existing_results ? nrow(filter(row -> row[1:ncol(tasks)]==task, results)) : 0
            for r in 1:session_params[:repetitions]
                task_start_time = now(UTC)
                n_curr_task += 1
                info(_LOGGER, "┌ $n_curr_task/$n_tasks: $case_string-$(task[:algorithm]) ($r/$(session_params[:repetitions]))")
                info(_LOGGER, "│ started at $(task_start_time)Z")
                if r > existing_tasks_like_this
                    task_dir = opt_params[:out_dir] = mkpath(joinpath(session_params[:tasks_dir], case_string, task[:algorithm], Dates.format(task_start_time,datetime_format)))
                    switch_log_file(joinpath(task_dir, "algorithm.log"))
                    termination_status, task_duration = optimize_case(case_data, task, opt_params)
                    if termination_status != _PM.OPTIMAL
                        Memento.warn(_LOGGER, "$case_string-$(task[:algorithm]): termination status is $(termination_status)")
                    end
                    switch_log_file(main_log_file)
                    push!(results, (task..., task_start_time, "$termination_status", task_duration))
                    CSV.write(results_file, results) # TODO: write just the new line istead of the whole table
                    info(_LOGGER, "└ completed in $(round(Int,task_duration)) s")
                else
                    info(_LOGGER, "└ skipped (reusing existing result)")
                end
            end
        end
    end
    return results
end
