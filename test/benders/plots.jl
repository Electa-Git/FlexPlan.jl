# Plots to analyze Benders decomposition procedure

using DataFrames
using StatsPlots

function make_benders_plots(data::Dict{String,Any}, result::Dict{String,Any}, out_dir::String; display_plots::Bool=true)
    stat = result["stat"]
    n_iter = length(stat)
    ub = [stat[i]["value"]["ub"] for i in 1:n_iter]
    lb = [stat[i]["value"]["lb"] for i in 1:n_iter]
    objective = [stat[i]["value"]["sol_value"] for i in 1:n_iter]
    objective_nonimproving = [stat[i]["value"]["current_best"] ? NaN : objective[i] for i in 1:n_iter]
    objective_improving = [stat[i]["value"]["current_best"] ? objective[i] : NaN for i in 1:n_iter]
    opt = result["objective"]

   # Solution value versus iterations
    plt = plot(1:n_iter, [ub, lb, objective_improving, objective_nonimproving];
        label      = ["UB" "LB" "improving solution" "non-improving solution"],
        seriestype = [:steppost :steppost :scatter :scatter],
        color      = [3 2 1 HSL(0,0,0.5)],
        ylims      = [lb[ceil(Int,n_iter/5)], maximum(objective[ceil(Int,n_iter/3):n_iter])],
        title      = "Benders decomposition solutions",
        ylabel     = "Cost",
        xlabel     = "Iterations",
        legend     = :topright,
    )
    savefig(plt, joinpath(out_dir,"sol.svg"))
    display_plots && display(plt)

    # Binary variable values versus iterations
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
    main_sol = Dict(i => Dict(year=>stat[i]["main"]["sol"][n] for (year,n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1))) for i in 1:n_iter)
    int_vars = DataFrame(name = String[], idx=Int[], year=Int[], legend = String[], values = Vector{Bool}[])
    for year in 1:_FP.dim_length(data, :year)
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
        yticks   = nrow(int_vars) <= 50 ? :all : :auto,
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
    display_plots && display(plt)

    # Solve time versus iterations
    main_time = [stat[i]["time"]["main"] for i in 1:n_iter]
    sec_time = [stat[i]["time"]["secondary"] for i in 1:n_iter]
    other_time = [stat[i]["time"]["other"] for i in 1:n_iter]
    plt1 = groupedbar(1:n_iter, [other_time sec_time main_time];
        bar_position = :stack,
        bar_width    = n_iter < 50 ? 0.8 : 1.0,
        color        = [HSL(0,0,2//3) 2 1],
        linewidth    = n_iter < 50 ? 1 : 0,
        title        = "Solve time",
        yguide       = "Time [s]",
        xguide       = "Iterations",
        legend       = :none,
    )
    plt2 = groupedbar([result["time"]["build"] result["time"]["main"] result["time"]["secondary"] result["time"]["other"]];
        bar_position     = :stack,
        orientation      = :horizontal,
        color            = [HSL(0,0,1//3) 1 2 HSL(0,0,2//3)],
        legend           = :outerright,
        label            = ["build model" "main problem" "secondary problems" "other"],
        grid             = :none,
        axis             = :hide,
        ticks            = :none,
        flip             = true,
        xguide           = "Total time: $(round(Int,result["time"]["total"])) s   —   Threads: $(Threads.nthreads())",
        xguidefontsize   = 9,
    )
    plt = plot(plt1, plt2; layout = grid(2,1; heights=[0.92, 0.08]))
    savefig(plt, joinpath(out_dir,"time.svg"))
    display_plots && display(plt)

    return nothing
end

# Plot of time vs. `x` variable (keeping other variables fixed). Used in performance tests.
function scatter_time_vs_variable(results::DataFrame, results_dir::String, fixed_vars::Vector{Symbol}, group_var::Symbol, x_var::Symbol)
    plots_data = groupby(results, fixed_vars)
    for k in keys(plots_data)
        data = select(plots_data[k], x_var, group_var, :time)
        if length(unique(data[!,group_var]))>1 && length(unique(data[!,x_var]))>1
            param_string = replace("$k"[12:end-1], '"' => "")
            x_min, x_max = extrema(data[!,x_var])
            x_logscale = x_min>0 && x_max/x_min > 10.0 # Whether to use log scale along x axis
            y_min, y_max = extrema(data.time)
            y_logscale = y_max/y_min > 10.0 # Whether to use log scale along y axis
            plt = @df data scatter(data[!,x_var], :time; group=data[!,group_var],
                title         = replace(param_string, r"(.+?, .+?, .+?, .+?,) "=>s"\1\n"), # Insert a newline every 4 params
                titlefontsize = 6,
                xlabel        = "$x_var",
                xscale        = x_logscale ? :log10 : :identity,
                xminorgrid    = x_logscale,
                xticks        = x_logscale ? :all : unique(data[!,x_var]),
                ylabel        = "Time [s]",
                yscale        = y_logscale ? :log10 : :identity,
                yminorgrid    = y_logscale,
                ylim          = [y_logscale ? -Inf : 0, Inf],
                legend        = :bottomright,
                legendtitle   = "$group_var"
            )
            #display(plt)
            plot_name = join(["$val" for val in k], "_") * ".svg"
            mkpath(joinpath(results_dir, "$group_var", "$x_var"))
            savefig(plt, joinpath(results_dir, "$group_var", "$x_var", plot_name))
        end
    end
end

function make_benders_perf_plots(results::DataFrame, results_dir::String)
    results_optimal = filter(row -> row.termination_status == "OPTIMAL", results)
    if nrow(results) != nrow(results_optimal)
        warn(_LOGGER, "Removed from analysis $(nrow(results)-nrow(results_optimal)) tests whose termination status is not OPTIMAL.")
    end

    param_variables = setdiff(propertynames(results_optimal), [:task_start_time, :termination_status, :time])
    for group in param_variables
        if length(unique(results_optimal[!,group])) > 1
            for x in param_variables
                if group≠x && eltype(results_optimal[!,x])<:Number && length(unique(results_optimal[!,x]))>1
                    fixed_vars = setdiff(param_variables, [group, x])
                    scatter_time_vs_variable(results_optimal, results_dir, fixed_vars, group, x)
                end
            end
        end
    end
    info(_LOGGER, "Plots saved in \"$results_dir\".")
end

function make_benders_perf_plots(results_dir::String)
    results = CSV.read(joinpath(results_dir, "results.csv"), DataFrame; pool=false, stringtype=String)
    make_benders_perf_plots(results, results_dir)
end
