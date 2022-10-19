# Data analysis and plotting related to decoupling of transmission and distribution

using Printf
using DataFrames
using StatsPlots

"""
    sol_report_decoupling_pcc_power(sol_up, sol_base, sol_down, data, surrogate; <keyword arguments>)

Report the imported active power at PCC.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol_up::Dict{String,Any}`: the solution Dict of the "up" case.
- `sol_base::Dict{String,Any}`: the solution Dict of the "base" case.
- `sol_down::Dict{String,Any}`: the solution Dict of the "down" case.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same optimization.
- `surrogate::Dict{String,Any}`: the surrogate model Dict, computed with `standalone=true`
  argument.
- `model_type::Type`: type of the model to instantiate.
- `optimizer`: the solver to use.
- `build_method::Function`: the function defining the optimization problem to solve.
- `ref_extensions::Vector{<:Function}=Function[]`: functions to apply during model
  instantiation.
- `solution_processors::Vector{<:Function}=Function[]`: functions to apply to results.
- `setting::Dict{String,Any}=Dict{String,Any}()`: to be passed to
  `_FP.TDDecoupling.run_td_decoupling_model`.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_decoupling_pcc_power(
        sol_up::Dict{String,Any},
        sol_base::Dict{String,Any},
        sol_down::Dict{String,Any},
        data::Dict{String,Any},
        surrogate::Dict{String,Any};
        model_type::Type,
        optimizer,
        build_method::Function,
        ref_extensions::Vector{<:Function} = Function[],
        solution_processors::Vector{<:Function} = Function[],
        setting::Dict{String,Any}=Dict{String,Any}(),
        out_dir::String=pwd(),
        table::String="",
        plot::String=""
    )

    _FP.require_dim(data, :hour, :scenario, :year, :sub_nw)
    data = deepcopy(data)
    dim = data["dim"]

    _FP.TDDecoupling.add_ne_branch_indicator!(data, sol_base)
    _FP.TDDecoupling.add_ne_storage_indicator!(data, sol_base)
    _FP.TDDecoupling.add_flex_load_indicator!(data, sol_base)
    sol_up_full = _FP.TDDecoupling.run_td_decoupling_model(data; model_type, optimizer, build_method=_FP.TDDecoupling.build_max_import_with_current_investments(build_method), ref_extensions, solution_processors, setting)
    sol_down_full = _FP.TDDecoupling.run_td_decoupling_model(data; model_type, optimizer, build_method=_FP.TDDecoupling.build_max_export_with_current_investments(build_method), ref_extensions, solution_processors, setting)

    sol_surrogate_up = _FP.TDDecoupling.run_td_decoupling_model(surrogate; model_type, optimizer, build_method=_FP.TDDecoupling.build_max_import(build_method), ref_extensions, solution_processors, setting)
    sol_surrogate_base = _FP.TDDecoupling.run_td_decoupling_model(surrogate; model_type, optimizer, build_method, ref_extensions, solution_processors, setting)
    sol_surrogate_down = _FP.TDDecoupling.run_td_decoupling_model(surrogate; model_type, optimizer, build_method=_FP.TDDecoupling.build_max_export(build_method), ref_extensions, solution_processors, setting)

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], p_up=Float64[], p_up_monotonic=Float64[], p_base=Float64[], p_down_monotonic=Float64[], p_down=Float64[], surr_up=Float64[], surr_base=Float64[], surr_down=Float64[])
    for n in _FP.nw_ids(dim)
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        push!(df, (h, s, y, sol_up_full["nw"]["$n"]["td_coupling"]["p"], sol_up["nw"]["$n"]["td_coupling"]["p"], sol_base["nw"]["$n"]["td_coupling"]["p"], sol_down["nw"]["$n"]["td_coupling"]["p"], sol_down_full["nw"]["$n"]["td_coupling"]["p"], sol_surrogate_up["nw"]["$n"]["td_coupling"]["p"], sol_surrogate_base["nw"]["$n"]["td_coupling"]["p"], sol_surrogate_down["nw"]["$n"]["td_coupling"]["p"]))
    end
    sort!(df, [:year, :scenario, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = select(gd[k], :hour, Not([:scenario, :year]))
            sort!(sdf, :hour)
            select!(sdf, Not(:hour))
            plt = @df sdf Plots.plot([:surr_up :surr_down],
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Imported power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = :right,
                legend_title = "Flexibility",
                legend_title_font_pointsize = 7,
                legend_font_pointsize = 6,
                label = ["surrogate up" "surrogate down"],
                seriestype = :stepmid,
                linewidth = 0.0,
                fillrange = :surr_base,
                fillalpha = 0.2,
                seriescolor = [HSLA(210,1,0.5,0) HSLA(0,0.75,0.5,0)],
                fillcolor = [HSL(210,1,0.5) HSL(0,0.75,0.5)],
            )
            @df sdf Plots.plot!(plt, [:p_up_monotonic :p_up :p_down_monotonic :p_down :p_base ],
                plot_title = "Power exchange at PCC",
                plot_titlevspan = 0.07,
                label = ["dist up monotonic" "dist up full" "dist down monotonic" "dist down full" "optimal planning"],
                seriestype = :stepmid,
                linestyle = [:dot :solid :dot :solid :solid],
                seriescolor = [HSL(210,1,0.5) HSL(210,1,0.5) HSL(0,0.75,0.5) HSL(0,0.75,0.5) HSL(0,0,0)],
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end
