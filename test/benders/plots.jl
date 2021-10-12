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
        ylims      = [lb[ceil(Int,n_iter/5)], maximum(objective[ceil(Int,n_iter/5):n_iter])],
        title      = "Benders decomposition solutions",
        ylabel     = "Cost",
        xlabel     = "Iterations",
        legend     = :topright,
    )
    savefig(plt, joinpath(out_dir,"sol_lin.svg"))
    display_plots && display(plt)

    plt = plot!(plt; yscale = :log10, ylims = [0.1opt, Inf])
    savefig(plt, joinpath(out_dir,"sol_log10.svg"))
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
    display_plots && display(plt)

    return nothing
end

# Plot of time vs. `x` variable (keeping other variables fixed). Used in performance tests.
function scatter_time_vs_variable(results::DataFrame, fixed_vars::Vector{Symbol}, x::Symbol)
    plots_data = groupby(results, fixed_vars)
    for k in keys(plots_data)
        data = select(plots_data[k], x, :algorithm, :time)
        plt = @df data scatter(data[!,"$x"], :time; group=:algorithm,
            title         = "$k"[12:end-1],
            titlefontsize = 9,
            xlabel        = "$x",
            ylabel        = "Time [s]",
            yscale        = :log10,
            yminorgrid    = true,
            legend        = :bottomright,
            legendtitle   = "Algorithm"
        )
        #display(plt)
        plot_name = replace("$k"[12:end-1] * ".svg", '"' => "")
        savefig(plt, joinpath(session_params[:results_dir], "$x", plot_name))
    end
end
