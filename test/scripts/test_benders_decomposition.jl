# Test of Benders decomposition


## Import packages and load common code

import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
using DataFrames
using Dates
using Memento
using Printf
using StatsPlots
include("../io/create_profile.jl")
# Solvers are imported later


## Input parameters

# Test case
test_case = "case6" # ONLY "case6" WORKS FOR NOW # Available test cases (see below): "case2", "case6", "cigre", "cigre_ext"
number_of_hours = 12 # Number of hourly optimization periods
number_of_scenarios = 8 # Number of scenarios (different generation/load profiles)
scale_cost = 1e-9 # Cost scale factor (to test the numerical tractability of the problem)

# Procedure
algorithm = _FP.Benders.Modern # `_FP.Benders.Classical` or `_FP.Benders.Modern`
obj_rtol = 1e-6 # Relative tolerance for stopping
max_iter = 1000 # Iteration limit
tightening_rtol = 1e-6 # Relative tolerance for adding optimality cuts
silent = true # Suppress solvers output, taking precedence over any other solver attribute

# Solvers
use_opensource_solvers = false # More options below

# Analysis and output
out_dir = "test/data/output_files"
make_plots = true # Plot solution value vs. iterations, decision variables vs. iterations, iteration times
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
        "CPXPARAM_MIP_Tolerances_MIPGap" => algorithm==_FP.Benders.Modern ? obj_rtol : 1e-4, # 1e-4 is CPLEX default
        "CPXPARAM_ScreenOutput" => 0, # ∈ {0,1}, default: 0
        "CPXPARAM_Output_CloneLog" => -1, # ∈ {-1,0,1}, default: 0
        "CPXPARAM_MIP_Display" => 2, # ∈ {0,...,5}, default: 2
    ) # Solver options: <https://www.ibm.com/docs/en/icos/20.1.0?topic=cplex-list-parameters>
    optimizer_LP = _FP.optimizer_with_attributes(CPLEX.Optimizer, # Log file would be interleaved in case of multiple scenarios. To enable logging, substitute with: _FP.optimizer_with_attributes(CPLEX_optimizer_with_logger("lp"),
        "CPXPARAM_LPMethod" => 2, # ∈ {0,...,6}, default: 0, <https://www.ibm.com/docs/en/icos/20.1.0?topic=parameters-algorithm-continuous-linear-problems>
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


## Process script parameters, set up logging

algorithm_name = last(split(string(algorithm),'.'))
optimizer_MILP_name = string(optimizer_MILP.optimizer_constructor)[1:end-10]
optimizer_LP_name = string(optimizer_LP.optimizer_constructor)[1:end-10]
param_string = @sprintf("%s_%04i_%02i_%s_%s_%s_%.0e", test_case, number_of_hours, number_of_scenarios, algorithm_name, optimizer_MILP_name, optimizer_LP_name, scale_cost)
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


## Test case preparation

if test_case == "case2" # Toy model 2-bus distribution network, single period

    file = "./test/data/case2.m" # Input case

    model_type = _FP.BFARadPowerModel
    data = _FP.parse_file(file)

elseif test_case == "case6" # 6-bus transmission network, max 8760 periods and 35 scenarios

    file = "./test/data/combined_td_model/t_case6.m"

    model_type = _PM.DCPPowerModel
    scenario = Dict{String, Any}("hours" => number_of_hours, "mc" => true, "sc_years" => Dict{String, Any}())
    for y in 1:number_of_scenarios
        sc_year = Dict{String, Any}()
        sc_year["year"] = y-1
        sc_year["probability"] = 1/number_of_scenarios
        scenario["sc_years"]["$y"] = sc_year
    end
    scenario["planning_horizon"] = 10
    data = _FP.parse_file(file, scenario; scale_cost)
    data, loadprofile, genprofile = create_profile_data_italy(data, scenario)
    extradata = _FP.create_profile_data(scenario["hours"]*length(data["scenario"]), data, loadprofile, genprofile)
    data = _FP.multinetwork_data(data, extradata)

elseif test_case == "cigre" # 15-bus distribution network, max 24 periods. CIGRE MV test network.

    file = "test/data/combined_td_model/d_cigre.m"
    scale_load = 3.0 # Scaling factor of loads
    scale_gen  = 1.0 # Scaling factor of generators

    model_type = _FP.BFARadPowerModel
    scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["probability"] = 1
    scenario["planning_horizon"] = 10
    data = _FP.parse_file(file, scenario; scale_cost)
    extradata = _FP.create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen)
    data = _FP.multinetwork_data(data, extradata)

elseif test_case == "cigre_ext" # 15-bus distribution network, max 8760 periods. CIGRE MV test network with extended gen/load profiles.

    file = "test/data/combined_td_model/d_cigre.m"
    scale_load = 3.0 # Scaling factor of loads
    scale_gen  = 1.0 # Scaling factor of generators

    model_type = _FP.BFARadPowerModel
    scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}())
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["probability"] = 1
    scenario["planning_horizon"] = 10
    data = _FP.parse_file(file, scenario; scale_cost)
    extradata = _FP.create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen, file_profiles_pu = "./test/data/CIGRE_profiles_per_unit_Italy.csv")
    data = _FP.multinetwork_data(data, extradata)

end


## Solve problem

info(script_logger, "Solving the problem with Benders decomposition...")
algo = algorithm == _FP.Benders.Classical ? algorithm(; obj_rtol, max_iter, tightening_rtol, silent) : algorithm(; max_iter, tightening_rtol, silent)
result_benders = _FP.run_benders_decomposition(
    algo,
    data, model_type,
    optimizer_MILP, optimizer_LP,
    number_of_scenarios == 1 ? _FP.post_flex_tnep_benders_main : _FP.post_stoch_flex_tnep_benders_main,
    number_of_scenarios == 1 ? _FP.post_flex_tnep_benders_secondary : _FP.post_stoch_flex_tnep_benders_secondary;
    ref_extensions = model_type == _PM.DCPPowerModel
        ? [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, _FP.add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!]
        : [_PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!, _FP.add_candidate_storage!],
    solution_processors = [_PM.sol_data_model!],
    setting = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
)


## Analyze result

# Proxy variables for convenience
if make_plots || compare_to_benchmark
    stat = result_benders["stat"]
    n_iter = length(stat)
    ub = [stat[i]["value"]["ub"] for i in 1:n_iter]
    lb = [stat[i]["value"]["lb"] for i in 1:n_iter]
    objective = [stat[i]["value"]["sol_value"] for i in 1:n_iter]
    objective_nonimproving = [stat[i]["value"]["current_best"] ? NaN : objective[i] for i in 1:n_iter]
    objective_improving = [stat[i]["value"]["current_best"] ? objective[i] : NaN for i in 1:n_iter]
    opt = result_benders["objective"]
    benders_sol = get(result_benders["solution"],"multinetwork",false) ? result_benders["solution"]["nw"]["1"] : result_benders["solution"]

    comp_name = Dict{String,String}(
        "ne_branch"   => "AC branch",
        "branchdc_ne" => "DC branch",
        "convdc_ne"   => "converter",
        "ne_storage"  => "storage",
        "load"        => "flex load"
    )
    comp_var = Dict{String,Symbol}(
        "ne_branch"   => :branch_ne,
        "branchdc_ne" => :branchdc_ne,
        "convdc_ne"   => :conv_ne,
        "ne_storage"  => :z_strg_ne,
        "load"        => :z_flex
    )
    comp_built = Dict{String,String}(
        "ne_branch"   => "built",
        "branchdc_ne" => "isbuilt",
        "convdc_ne"   => "isbuilt",
        "ne_storage"  => "isbuilt",
        "load"        => "isflex"
    )
end


## Make plots

if make_plots

    # Solution value versus iterations
    plt = plot(1:n_iter, [ub, lb, objective_improving, objective_nonimproving];
        label      = ["UB" "LB" "improving solution" "non-improving solution"],
        seriestype = [:steppost :steppost :scatter :scatter],
        color      = [3 2 1 HSL(0,0,0.5)],
        ylims      = [lb[ceil(Int,n_iter/5)], maximum(objective[ceil(Int,n_iter/5):n_iter])],
        title      = "Benders decomposition solutions",
        ylabel     = "Cost",
        xlabel     = "Iterations",
        legend     = :topright,
    )
    savefig(plt, joinpath(out_dir,"sol_lin.svg"))
    display(plt)

    plt = plot!(plt; yscale = :log10, ylims = [0.1opt, Inf])
    savefig(plt, joinpath(out_dir,"sol_log10.svg"))
    display(plt)

    # Binary variable values versus iterations
    main_sol = get(result_benders["solution"],"multinetwork",false) ? [stat[i]["main"]["sol"][1] for i in 1:n_iter] : [stat[i]["main"]["sol"][0] for i in 1:n_iter]
    int_vars = DataFrame(name = String[], idx=Int[], legend = String[], values = Vector{Bool}[])
    for (comp, name) in comp_name
        var = comp_var[comp]
        if haskey(first(main_sol), var)
            for idx in keys(first(main_sol)[var])
                push!(int_vars, (name, idx, "$name $idx", [main_sol[i][var][idx] for i in 1:n_iter]))
            end
        end
    end
    sort!(int_vars, [:name, :idx])
    select!(int_vars, :legend, :values)
    values_matrix = Array{Int}(undef, nrow(int_vars), n_iter)
    for n in 1:nrow(int_vars)
        values_matrix[n,:] = int_vars.values[n]
    end
    values_matrix_plot = values_matrix + repeat(2isfinite.(objective_improving)', nrow(int_vars))
    # | value | color      | component built? | improving iteration? |
    # | ----- | ---------- | ---------------- | -------------------- |
    # |     0 | light grey |        no        |          no          |
    # |     1 | dark grey  |       yes        |          no          |
    # |     2 | light blue |        no        |         yes          |
    # |     3 | dark blue  |       yes        |         yes          |
    palette = cgrad([HSL(0,0,0.75), HSL(0,0,0.5), HSL(203,0.5,0.76), HSL(203,0.5,0.51)], 4, categorical = true)
    plt = heatmap(1:n_iter, int_vars.legend, values_matrix_plot;
        yflip    = true,
        yticks   = :all,
        title    = "Investment decisions",
        ylabel   = "Components",
        xlabel   = "Iterations",
        color    = palette,
        colorbar = :none,
        #legend   = :outerbottom
    )
    #for (idx, lab) in enumerate(["not built, non-improving iteration", "built, non-improving iteration", "not built, improving iteration", "built, improving iteration"])
    #    plot!([], [], seriestype=:shape, label=lab, color=palette[idx])
    #end
    savefig(plt, joinpath(out_dir,"intvars.svg"))
    display(plt)

    # Solve time versus iterations
    main_time = [stat[i]["time"]["main"] for i in 1:n_iter]
    sec_time = [stat[i]["time"]["secondary"] for i in 1:n_iter]
    other_time = [stat[i]["time"]["other"] for i in 1:n_iter]
    plt = groupedbar(1:n_iter, [other_time sec_time main_time];
        label        = ["other" "secondary problems" "main problem"],
        bar_position = :stack,
        bar_width    = n_iter < 50 ? 0.8 : 1.0,
        color        = [HSL(0,0,0.5) 2 1],
        linewidth    = n_iter < 50 ? 1 : 0,
        title        = "Solve time",
        ylabel       = "Time [s]",
        xlabel       = "Iterations",
        legend       = :top,
    )
    savefig(plt, joinpath(out_dir,"time.svg"))
    display(plt)
end


## Solve benchmark and compare

if compare_to_benchmark
    info(script_logger, "Solving the problem as MILP...")
    time_benchmark_start = time()
    result_benchmark = (number_of_scenarios == 1
        ? _FP.flex_tnep(data, model_type, optimizer_benchmark; multinetwork=_PM._IM.ismultinetwork(data), setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false))
        : _FP.stoch_flex_tnep(data, model_type, optimizer_benchmark; multinetwork=_PM._IM.ismultinetwork(data), setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)) )
    @assert result_benchmark["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
    time_benchmark = time() - time_benchmark_start
    info(script_logger, @sprintf("MILP time: %.1f s", time_benchmark)) # result_benchmark["solve_time"] does not include model build time
    info(script_logger, @sprintf("Benders/MILP solve time ratio: %.3f", result_benders["solve_time"]/time_benchmark))

    # Test solution correctness

    if !isapprox(opt, result_benchmark["objective"]; rtol=obj_rtol)
        warn(script_logger, "Benders procedure failed to find an optimal solution within tolerance (benders $opt, benchmark $(result_benchmark["objective"]))")
    end
    benchmark_sol = get(result_benchmark["solution"],"multinetwork",false) ? result_benchmark["solution"]["nw"]["1"] : result_benchmark["solution"]
    for (comp, name) in comp_name
        built = comp_built[comp]
        if haskey(benchmark_sol, comp)
            for idx in keys(benchmark_sol[comp])
                benchmark_value = benchmark_sol[comp][idx][built]
                benders_value = benders_sol[comp][idx][built]
                if !isapprox(benders_value, benchmark_value, atol=1e-1)
                    warn(script_logger, "Activation variable of $name $idx in Benders decomposition solution does not match benchmark solution (benders $benders_value, benchmark $benchmark_value)")
                end
            end
        end
    end
end


println("Output files saved in \"$out_dir\"")
info(script_logger, "Test completed")
