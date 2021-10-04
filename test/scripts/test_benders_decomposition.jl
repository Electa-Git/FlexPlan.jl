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
include("../io/multiple_years.jl")
# Solvers are imported later


## Input parameters

# Test case
test_case = "case6" # Available test cases (see below): "case6", "case67", "cigre", "cigre_ext", "case2"
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


## Test case preparation

if test_case in ["case6", "case67"]
    # `case6`:   6-bus transmission network. Max 8760 hours, 35 scenarios, 3 years.
    # `case67`: 67-bus transmission network. Max 8760 hours,  3 scenarios, 3 years.

    model_type = _PM.DCPPowerModel
    data = create_multi_year_network_data(test_case, number_of_hours, number_of_scenarios, number_of_years; cost_scale_factor = scale_cost)

elseif test_case in ["cigre", "cigre_ext"]
    # `cigre`:     15-bus distribution network. Max   24 hours, 1 scenario, 1 year.
    # `cigre_ext`: 15-bus distribution network. Max 8760 hours, 1 scenario, 1 year.

    scale_load = 3.0 # Scale factor of loads
    scale_gen  = 1.0 # Scale factor of generators
    model_type = _FP.BFARadPowerModel
    file = "test/data/combined_td_model/d_cigre.m"
    file_profiles_pu = test_case == "cigre" ? "./test/data/CIGRE_profiles_per_unit.csv" : "./test/data/CIGRE_profiles_per_unit_Italy.csv"
    data = _FP.parse_file(file)
    _FP.add_dimension!(data, :hour, number_of_hours)
    _FP.add_dimension!(data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios))
    _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>10))
    _FP.scale_data!(data; cost_scale_factor = scale_cost) # Add `year_idx` parameter when using on multi-year instances
    time_series = create_profile_data_cigre(data, number_of_hours; scale_load, scale_gen, file_profiles_pu)
    data = _FP.make_multinetwork(data, time_series)

elseif test_case == "case2"
    # `case2`: 2-bus distribution network. Max 1 hour, 1 scenario, 1 year.

    model_type = _FP.BFARadPowerModel
    file = "./test/data/case2.m"
    data = _FP.parse_file(file)
    _FP.add_dimension!(data, :hour, number_of_hours)
    _FP.add_dimension!(data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/number_of_scenarios) for s in 1:number_of_scenarios))
    _FP.add_dimension!(data, :year, number_of_years; metadata = Dict{String,Any}("scale_factor"=>10))
    _FP.scale_data!(data; cost_scale_factor = scale_cost)
    data = _FP.make_multinetwork(data)

else
    Memento.error(script_logger, "Test case \"$test_case\" not implemented.")

end


## Solve problem

info(script_logger, "Solving the problem with Benders decomposition...")
algo = algorithm == _FP.Benders.Classical ? algorithm(; obj_rtol, max_iter, tightening_rtol, silent) : algorithm(; max_iter, tightening_rtol, silent)
result_benders = _FP.run_benders_decomposition(
    algo,
    data, model_type,
    optimizer_MILP, optimizer_LP,
    _FP.post_stoch_flex_tnep_benders_main,
    _FP.post_stoch_flex_tnep_benders_secondary;
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
    benders_sol = Dict(year => result_benders["solution"]["nw"]["$n"] for (year, n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1)))

    comp_name = Dict{String,String}(
        "ne_branch"   => "AC branch",
        "branchdc_ne" => "DC branch",
        "convdc_ne"   => "converter",
        "ne_storage"  => "storage",
        "load"        => "flex load"
    )
    comp_var = Dict{String,Symbol}(
        "ne_branch"   => :branch_ne_investment,
        "branchdc_ne" => :branchdc_ne_investment,
        "convdc_ne"   => :conv_ne_investment,
        "ne_storage"  => :z_strg_ne_investment,
        "load"        => :z_flex_investment
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
    main_sol = Dict(i => Dict(year=>stat[i]["main"]["sol"][n] for (year,n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1))) for i in 1:n_iter)
    int_vars = DataFrame(name = String[], idx=Int[], year=Int[], legend = String[], values = Vector{Bool}[])
    for year in 1:number_of_years
        for (comp, name) in comp_name
            var = comp_var[comp]
            if haskey(main_sol[1][year], var)
                for idx in keys(main_sol[1][year][var])
                    push!(int_vars, (name, idx, year, "$name $idx (y$year)", [main_sol[i][year][var][idx] for i in 1:n_iter]))
                end
            end
        end
    end
    sort!(int_vars, [:name, :idx, :year])
    select!(int_vars, :legend, :values)
    values_matrix = Array{Int}(undef, nrow(int_vars), n_iter)
    for n in 1:nrow(int_vars)
        values_matrix[n,:] = int_vars.values[n]
    end
    values_matrix_plot = values_matrix + repeat(2isfinite.(objective_improving)', nrow(int_vars))
    # | value | color      | invested in component? | improving iteration? |
    # | ----- | ---------- | ---------------------- | -------------------- |
    # |     0 | light grey |           no           |          no          |
    # |     1 | dark grey  |          yes           |          no          |
    # |     2 | light blue |           no           |         yes          |
    # |     3 | dark blue  |          yes           |         yes          |
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
    result_benchmark = _FP.stoch_flex_tnep(data, model_type, optimizer_benchmark; setting=Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false))
    @assert result_benchmark["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result_benchmark["optimizer"]) termination status: $(result_benchmark["termination_status"])"
    result_benchmark["time"] = Dict{String,Any}("total" => time()-time_benchmark_start)
    info(script_logger, @sprintf("MILP time: %.1f s", result_benchmark["time"]["total"])) # result_benchmark["solve_time"] does not include model build time
    info(script_logger, @sprintf("Benders/MILP solve time ratio: %.3f", result_benders["time"]["total"]/result_benchmark["time"]["total"]))

    # Test solution correctness

    if !isapprox(opt, result_benchmark["objective"]; rtol=obj_rtol)
        bench_opt = result_benchmark["objective"]
        warn(script_logger, @sprintf("Benders procedure failed to find an optimal solution within tolerance %.2e", obj_rtol))
        warn(script_logger, @sprintf("            (benders % 15.9g, benchmark % 15.9g, rtol %.2e)", opt, bench_opt, opt/bench_opt-1))
    end
    benchmark_sol = Dict(year => result_benchmark["solution"]["nw"]["$n"] for (year, n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1)))
    for y in 1:number_of_years
        for (comp, name) in comp_name
        if haskey(benchmark_sol[y], comp)
            for idx in keys(benchmark_sol[y][comp])
                    benchmark_value = benchmark_sol[y][comp][idx]["investment"]
                    benders_value = benders_sol[y][comp][idx]["investment"]
                    if !isapprox(benders_value, benchmark_value, atol=1e-1)
                        warn(script_logger, "In year $y, the investment decision for $name $idx does not match (Benders $(round(Int,benders_value)), benchmark $(round(Int,benchmark_value)))")
                    end
                end
            end
        end
    end
end


println("Output files saved in \"$out_dir\"")
info(script_logger, "Test completed")
