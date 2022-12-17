# Tools for analyzing the solution of a FlexPlan optimization problem

using CSV
using DataFrames
import GR
using Graphs
using GraphRecipes
using Printf
import Random
using StatsPlots

"""
    sol_graph(sol, data; <keyword arguments>)

Plot a graph of the network with bus numbers and active power of branches.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `plot::String`: output a plot to `plot` file; file type is based on `plot` extension.
- `kwargs...`: specify dimensions and coordinates for which to generate plots, like
  `hour=[12,24]`.
"""
function sol_graph(sol::Dict{String,Any}, data::Dict{String,Any}; plot::String, out_dir::String=pwd(), kwargs...)
    for n in _FP.nw_ids(data; kwargs...)
        plt = _sol_graph(sol["nw"]["$n"], data["nw"]["$n"])
        name, ext = splitext(plot)
        for d in reverse(_FP.dim_names(data))
            if _FP.dim_length(data, d) > 1
                name *= "_$(string(d)[1])$(_FP.coord(data,n,d))"
            end
        end
        savefig(plt, joinpath(out_dir, "$name$ext"))
    end
end

function _sol_graph(sol::Dict{String,Any}, data::Dict{String,Any})
    # Collect digraph edges (bus pairs) and edge labels (branch active power)
    edge_power = Dict{Tuple{Int,Int},Float64}() # Key: edge; value: power.
    for (b,sol_br) in sol["branch"]
        data_br = data["branch"][b]
        f_bus = data_br["f_bus"]
        t_bus = data_br["t_bus"]
        p = sol_br["pf"]
        edge_power[(f_bus,t_bus)] = p
    end
    for (b,sol_br) in get(sol, "ne_branch", Dict())
        if sol_br["built"] > 0.5
            data_br = data["ne_branch"][b]
            f_bus = data_br["f_bus"]
            t_bus = data_br["t_bus"]
            curr_p = sol_br["pf"]
            prev_p = get(edge_power, (f_bus,t_bus), 0.0)
            edge_power[(f_bus,t_bus)] = prev_p + curr_p # Sum power in case a candidate branch is added in parallel to an existing one.
        end
    end
    n_bus = length(data["bus"])
    node_names = string.(1:n_bus)

    if haskey(sol,"convdc") || haskey(sol,"convdc_ne") || haskey(sol,"branchdc")
        n_ac_bus = n_bus
        node_names = "AC" .* string.(1:n_bus)
        for (c,sol_conv) in get(sol,"convdc",Dict())
            data_conv = data["convdc"][c]
            ac_bus = data_conv["busac_i"]
            dc_bus = data_conv["busdc_i"]
            p = sol_conv["pconv"] # Converters are lossy; here we take the AC side power (load convention).
            edge_power[(ac_bus,dc_bus+n_ac_bus)] = p
        end
        for (c,sol_conv) in get(sol,"convdc_ne",Dict())
            if sol_conv["isbuilt"] > 0.5
                data_conv = data["convdc_ne"][c]
                ac_bus = data_conv["busac_i"]
                dc_bus = data_conv["busdc_i"]
                curr_p = sol_conv["pconv"] # Converters are lossy; here we take the AC side power (load convention).
                prev_p = get(edge_power, (ac_bus,dc_bus+n_ac_bus), 0.0)
                edge_power[(ac_bus,dc_bus+n_ac_bus)] = prev_p + curr_p # Sum power in case a candidate converter is added in parallel to an existing one.
            end
        end
        for (b,sol_br) in sol["branchdc"]
            data_br = data["branchdc"][b]
            f_bus = data_br["fbusdc"]
            t_bus = data_br["tbusdc"]
            p = sol_br["pf"]
            edge_power[(f_bus+n_ac_bus,t_bus+n_ac_bus)] = p
        end
        for (b,sol_br) in get(sol, "branchdc_ne", Dict())
            if sol_br["isbuilt"] > 0.5
                data_br = data["branchdc_ne"][b]
                f_bus = data_br["fbusdc"]
                t_bus = data_br["tbusdc"]
                curr_p = sol_br["pf"]
                prev_p = get(edge_power, (f_bus+n_ac_bus,t_bus+n_ac_bus), 0.0)
                edge_power[(f_bus+n_ac_bus,t_bus+n_ac_bus)] = prev_p + curr_p # Sum power in case a candidate branch is added in parallel to an existing one.
            end
        end
        n_bus = maximum([max(i,j) for (i,j) in keys(edge_power)])
        n_dc_bus = n_bus - n_ac_bus
        append!(node_names, "DC" .* string.(1:n_dc_bus))
    end

    # Orient digraph edges according to power flow
    for (s,d) in collect(keys(edge_power)) # collect is needed because we want to mutate edge_power.
        if edge_power[(s,d)] < 0
            edge_power[(d,s)] = -edge_power[(s,d)]
            delete!(edge_power, (s,d))
        end
    end

    # Generate digraph
    g = SimpleDiGraph(n_bus)
    for (s,d) in keys(edge_power)
        add_edge!(g, s, d)
    end

    # Generate plot
    edge_power_rounded = Dict(e => round(p;sigdigits=2) for (e,p) in edge_power) # Shorten edge labels preserving only most useful information.
    node_weights = 1 ./ length.(node_names)
    function calc_node_weight(name) # Hack to make all nodes the same size.
        len = length(name)
        len == 1 ? 10.0 : 1/len
    end
    Random.seed!(1) # To get reproducible results. Keep until GraphRecipes allows to pass seed as an argument to NetworkLayout functions.
    GR.setarrowsize(10/n_bus) # Keep until Plots implements arrow size.
    plt = graphplot(g;
        size = (300*sqrt(n_bus),300*sqrt(n_bus)),
        method = :stress,
        names = node_names,
        nodeshape = :circle,
        nodesize = 0.15,
        node_weights = calc_node_weight.(node_names),
        nodecolor = HSL(0,0,1),
        nodestrokecolor = HSL(0,0,0.5),
        linewidth = 2,
        edgelabel = edge_power_rounded,
        curves = false,
        curvature_scalar = 0.0,
        arrow = :filled,
    )
    return plt
end

"""
    sol_report_cost_summary(sol, data; <keyword arguments>)

Report the objective cost by network component and cost category.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `td_coupling::Bool=true`: whether to include cost of energy exchanged with other networks.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_cost_summary(sol::Dict{String,Any}, data::Dict{String,Any}; td_coupling::Bool=true, out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]
    sol_nw = sol["nw"]
    data_nw = data["nw"]

    function sum_investment_cost(single_nw_cost::Function)
        sum(single_nw_cost(data_nw[n], sol_nw[n]) for n in string.(_FP.nw_ids(dim; hour=1, scenario=1)))
    end
    function sum_operation_cost(single_nw_cost::Function)
        sum(scenario["probability"] * sum(single_nw_cost(data_nw[n], sol_nw[n], n) for n in string.(_FP.nw_ids(dim; scenario=s))) for (s, scenario) in _FP.dim_prop(dim, :scenario))
    end

    df = DataFrame(component=String[], inv=Float64[], op=Float64[], shift=Float64[], red=Float64[], curt=Float64[])

    inv = sum_investment_cost((d,s) -> sum(d["ne_branch"][i]["construction_cost"] for (i,branch) in get(s,"ne_branch",Dict()) if branch["investment"]>0.5; init=0.0))
    push!(df, ("AC branches", inv, 0.0, 0.0, 0.0, 0.0))

    inv = sum_investment_cost((d,s) -> sum(d["convdc_ne"][i]["cost"] for (i,conv) in get(s,"convdc_ne",Dict()) if conv["investment"]>0.5; init=0.0))
    push!(df, ("converters", inv, 0.0, 0.0, 0.0, 0.0))

    inv = sum_investment_cost((d,s) -> sum(d["branchdc_ne"][i]["cost"] for (i,branch) in get(s,"branchdc_ne",Dict()) if branch["investment"]>0.5; init=0.0))
    push!(df, ("DC branches", inv, 0.0, 0.0, 0.0, 0.0))

    inv = sum_investment_cost((d,s) -> sum(d["load"][i]["cost_inv"] for (i,load) in s["load"] if get(load,"investment",0.0)>0.5; init=0.0))
    shift = sum_operation_cost((d,s,n) -> sum(get(d["load"][i],"cost_shift",0.0) * 0.5*(load["pshift_up"]+load["pshift_down"]) for (i,load) in s["load"]; init=0.0))
    red = sum_operation_cost((d,s,n) -> sum(get(d["load"][i],"cost_red",0.0) * load["pred"] for (i,load) in s["load"]; init=0.0))
    curt = sum_operation_cost((d,s,n) -> sum(d["load"][i]["cost_curt"] * load["pcurt"] for (i,load) in s["load"]; init=0.0))
    push!(df, ("loads", inv, 0.0, shift, red, curt))

    inv = sum_investment_cost((d,s) -> sum(d["ne_storage"][i]["eq_cost"]+d["ne_storage"][i]["inst_cost"] for (i,storage) in get(s,"ne_storage",Dict()) if storage["investment"]>0.5; init=0.0))
    push!(df, ("storage", inv, 0.0, 0.0, 0.0, 0.0))

    op = sum_operation_cost((d,s,n) -> sum((length(d["gen"][i]["cost"])≥2 ? d["gen"][i]["cost"][end-1] : 0.0) * gen["pg"] for (i,gen) in s["gen"]; init=0.0))
    curt = sum_operation_cost((d,s,n) -> sum(get(d["gen"][i],"cost_curt",0.0) * gen["pgcurt"] for (i,gen) in s["gen"]; init=0.0))
    push!(df, ("generators", 0.0, op, 0.0, 0.0, curt))

    if td_coupling && _FP.has_dim(data, :sub_nw)
        op = sum_operation_cost((d,s,n) ->
            begin
                d_gen = string(_FP.dim_prop(dim,:sub_nw,_FP.coord(dim,parse(Int,n),:sub_nw),"d_gen"))
                cost_vector = d["gen"][d_gen]["cost"]
                (length(cost_vector)≥2 ? cost_vector[end-1] : 0.0) * s["td_coupling"]["p"]
            end
        )
        push!(df, ("T-D coupling", 0.0, op, 0.0, 0.0, 0.0))
    end

    if !isempty(plot)
        total_cost = sum(sum(df[:,col]) for col in 2:ncol(df))
        horizon = _FP.dim_meta(dim, :year, "scale_factor")
        total_cost_string = @sprintf("total: %g over %i ", total_cost, horizon) * (horizon==1 ? "year" : "years")
        plt = @df df groupedbar(:component, [:curt :red :shift :op :inv];
            bar_position = :stack,
            plot_title = "Cost",
            plot_titlevspan = 0.07,
            title = total_cost_string,
            titlefontsize = 8,
            legend_position = :topleft,
            xguide = "Network components",
            xtickfontsize = nrow(df) ≤ 6 ? 8 : 7,
            framestyle = :zerolines,
            xgrid = :none,
            linecolor = HSLA(0,0,1,0),
            label = ["curtailment" "voluntary reduction" "time shifting" "normal operation" "investment"],
            seriescolor = [HSLA(0,1,0.5,0.75) HSLA(0,0.67,0.5,0.75) HSLA(0,0.33,0.5,0.75) HSLA(0,0,0.5,0.75) HSLA(210,0.75,0.5,0.75)],
        )
        savefig(plt, joinpath(out_dir,plot))
    end

    # Add row of totals
    df2 = combine(df, Not(:component) .=> sum; renamecols=false)
    df2[!,:component] .= "total"
    df = vcat(df,df2)

    # Add column of totals
    transform!(df, Not(:component) => ByRow(+) => :total)

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    return df
end

"""
    sol_report_investment(sol, data; <keyword arguments>)

Report investment decisions made in `sol`.

Return a DataFrame; optionally write a CSV table.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
"""
function sol_report_investment(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(component=String[], id=Int[], source_id=String[], year=Int[], investment=Bool[])
    for n in _FP.nw_ids(dim; hour=1, scenario=1)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        y = _FP.coord(dim, n, :year)

        for (b,br_sol) in get(sol_nw,"ne_branch",Dict())
            br_data = data_nw["ne_branch"][b]
            push!(df, ("ne_branch", parse(Int,b), string(last(br_data["source_id"])), y, br_sol["investment"]>0.5))
        end

        for (c,conv_sol) in get(sol_nw,"convdc_ne",Dict())
            conv_data = data_nw["convdc_ne"][c]
            push!(df, ("convdc_ne", parse(Int,c), string(last(conv_data["source_id"])), y, conv_sol["investment"]>0.5))
        end

        for (b,br_sol) in get(sol_nw,"branchdc_ne",Dict())
            br_data = data_nw["branchdc_ne"][b]
            push!(df, ("branchdc_ne", parse(Int,b), string(last(br_data["source_id"])), y, br_sol["investment"]>0.5))
        end

        for (s,storage_sol) in get(sol_nw,"ne_storage",Dict())
            storage_data = data_nw["ne_storage"][s]
            push!(df, ("ne_storage", parse(Int,s), string(last(storage_data["source_id"])), y, storage_sol["investment"]>0.5))
        end

        for (l,load_sol) in get(sol_nw,"load",Dict())
            load_data = data_nw["load"][l]
            if load_data["flex"] > 0.5 # Loads that can be made flexible
                push!(df, ("load", parse(Int,l), string(last(load_data["source_id"])), y, load_sol["investment"]>0.5))
            end
        end
    end
    sort!(df, [:component, :id, :year])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    return df
end

"""
    sol_report_investment_summary(sol, data; <keyword arguments>)

Report a summary of investments made in `sol`.

Categorize network component in: _existing_, _activated candidates_, and _not activated
candidates_.
Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_investment_summary(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(component=String[], year=Int[], existing=Int[], candidate_on=Int[], candidate_off=Int[])
    for n in _FP.nw_ids(dim; hour=1, scenario=1)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        y = _FP.coord(dim, n, :year)

        existing = length(sol_nw["branch"])
        candidate = length(get(sol_nw,"ne_branch",Dict()))
        candidate_on = round(Int, sum(br["built"] for br in values(get(sol_nw,"ne_branch",Dict())); init=0.0))
        candidate_off = candidate - candidate_on
        push!(df, ("AC branches", y, existing, candidate_on, candidate_off))

        existing = length(get(sol_nw,"convdc",Dict()))
        candidate = length(get(sol_nw,"convdc_ne",Dict()))
        candidate_on = round(Int, sum(st["isbuilt"] for st in values(get(sol_nw,"convdc_ne",Dict())); init=0.0))
        candidate_off = candidate - candidate_on
        push!(df, ("AC/DC converters", y, existing, candidate_on, candidate_off))

        existing = length(get(sol_nw,"branchdc",Dict()))
        candidate = length(get(sol_nw,"branchdc_ne",Dict()))
        candidate_on = round(Int, sum(br["isbuilt"] for br in values(get(sol_nw,"branchdc_ne",Dict())); init=0.0))
        candidate_off = candidate - candidate_on
        push!(df, ("DC branches", y, existing, candidate_on, candidate_off))

        existing = length(sol_nw["gen"])
        push!(df, ("generators", y, existing, 0, 0))

        existing = length(get(sol_nw,"storage",Dict()))
        candidate = length(get(sol_nw,"ne_storage",Dict()))
        candidate_on = round(Int, sum(st["isbuilt"] for st in values(get(sol_nw,"ne_storage",Dict())); init=0.0))
        candidate_off = candidate - candidate_on
        push!(df, ("storage devices", y, existing, candidate_on, candidate_off))

        candidate = round(Int, sum(load["flex"] for load in values(data_nw["load"])))
        existing = length(sol_nw["load"]) - candidate
        candidate_on = round(Int, sum(load["flex"] for load in values(sol_nw["load"])))
        candidate_off = candidate - candidate_on
        push!(df, ("loads", y, existing, candidate_on, candidate_off))
    end
    sort!(df, [:component, :year])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        rdf = reverse(df)
        rdf.name = maximum(rdf.year) == 1 ? rdf.component : rdf.component .* " - y" .* string.(rdf.year)
        plt = @df rdf groupedbar([:candidate_off :candidate_on :existing];
            bar_position = :stack,
            orientation = :h,
            plot_title = "Investments",
            yguide = "Network components",
            xguide = "Count",
            framestyle = :grid,
            yticks = (1:nrow(rdf), :name),
            ygrid = :none,
            linecolor = HSLA(0,0,1,0),
            label = ["not activated candidates" "activated candidates" "existing"],
            legend_position = :bottomright,
            seriescolor = [HSLA(0,0,0.75,0.75) HSLA(210,0.75,0.67,0.75) HSLA(210,1,0.33,0.75)],
        )
        vline!(plt, [0]; seriescolor=HSL(0,0,0), label=:none)
        savefig(plt, joinpath(out_dir,plot))
    end

    return df
end

"""
    sol_report_power_summary(sol, data; <keyword arguments>)

Report the absorbed/injected active power by component type, using load convention.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_power_summary(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]
    sol_nw = sol["nw"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], load=Float64[], storage_abs=Float64[], storage_inj=Float64[], gen=Float64[])
    for n in _FP.nw_ids(dim)
        nw = sol_nw["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        load = sum(load["pflex"] for load in values(nw["load"]))
        storage_abs =  sum(storage["sc"] for storage in values(get(nw,"storage",Dict())); init=0.0) + sum(storage["sc_ne"] for storage in values(get(nw,"ne_storage",Dict())); init=0.0)
        storage_inj = -sum(storage["sd"] for storage in values(get(nw,"storage",Dict())); init=0.0) - sum(storage["sd_ne"] for storage in values(get(nw,"ne_storage",Dict())); init=0.0)
        gen = -sum(gen["pg"] for gen in values(nw["gen"]); init=0.0)
        push!(df, (h, s, y, load, storage_abs, storage_inj, gen))
    end

    if _FP.has_dim(data, :sub_nw)
        df.td_coupling = [sol_nw["$n"]["td_coupling"]["p"] for n in _FP.nw_ids(dim)]
    end

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = gd[k]
            plt = @df sdf groupedbar([:load :storage_abs :storage_inj :gen],
                bar_position = :stack,
                plot_title = "Aggregated power",
                plot_titlevspan = 0.07,
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Absorbed power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                bar_width = 1,
                linecolor = HSLA(0,0,1,0),
                legend_position = :bottomright,
                label = ["demand" "storage absorption" "storage injection" "generation"],
                seriescolor = [HSLA(210,1,0.67,0.75) HSLA(210,1,0.33,0.75) HSLA(0,0.75,0.33,0.75) HSLA(0,0.75,0.67,0.75)],
            )
            if :td_coupling in propertynames(sdf)
                @df sdf plot!(plt, :td_coupling; label="T&D coupling", seriestype=:stepmid, linecolor=:black)
            end
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_branch(sol, data; <keyword arguments>)

Report the active, reactive, and relative active power of branches.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
- `rated_power_scale_factor::Float64=1.0`: scale the rated power further.
"""
function sol_report_branch(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="", rated_power_scale_factor::Float64=1.0)
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], component=String[], id=Int[], source_id=String[], p=Float64[], q=Float64[], p_rel=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for comp in ("branch", "ne_branch")
            for (b, br) in get(sol_nw, comp, Dict{String,Any}())
                data_br = data_nw[comp][b]
                source_id = string(data_br["source_id"][end])
                rate = data_br["rate_a"]
                p = br["pf"]
                q = br["qf"]
                p_rel = abs(p) / (rated_power_scale_factor * rate)
                push!(df, (h, s, y, comp, parse(Int,b), source_id, p, q, p_rel))
            end
        end
    end
    sort!(df, [:year, :scenario, :component, :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = select(gd[k], :hour, [:component,:id] => ByRow((c,i)->"$(c)_$i") => :comp_id, :p_rel)
            sdf = unstack(sdf, :comp_id, :p_rel)
            sort!(sdf, :hour)
            few_branches = ncol(sdf) ≤ 24
            plt = @df sdf Plots.plot(:hour, cols(2:ncol(sdf)),
                plot_title = "Relative active power of branches",
                plot_titlevspan = 0.07,
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Relative active power",
                ylims = (0,1),
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_branches ? :outertopright : :none,
                seriestype = :stepmid,
                fillrange = 0.0,
                fillalpha = 0.05,
                seriescolor = few_branches ? :auto : HSL(210,0.75,0.5),
                linewidth = few_branches ? 1.0 : 0.5,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_bus_voltage_angle(sol, data; <keyword arguments>)

Report bus voltage angle.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_bus_voltage_angle(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], id=Int[], source_id=String[], va=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (i,bus) in sol_nw["bus"]
            source_id = string(data_nw["bus"][i]["source_id"][end])
            push!(df, (h, s, y, parse(Int,i), source_id, bus["va"]))
        end
    end
    sort!(df, [:year, :scenario, :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = select(gd[k], :hour, :id, :va)
            few_buses = length(unique(sdf.id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Voltage angle [rad]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_buses ? :outertopright : :none,
            )
            gsd = groupby(sdf, :id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :va)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :va;
                    seriestype = :stepmid,
                    fillrange = 0.0,
                    fillalpha = 0.05,
                    linewidth = few_buses ? 1.0 : 0.5,
                    seriescolor = few_buses ? :auto : HSL(0,0,0),
                    label = "bus_$(i.id)",
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Buses",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_bus_voltage_magnitude(sol, data; <keyword arguments>)

Report bus voltage magnitude.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_bus_voltage_magnitude(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], id=Int[], source_id=String[], vm=Float64[], vmin=Float64[], vmax=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (i,bus) in sol_nw["bus"]
            source_id = string(data_nw["bus"][i]["source_id"][end])
            vmin = data_nw["bus"][i]["vmin"]
            vmax = data_nw["bus"][i]["vmax"]
            push!(df, (h, s, y, parse(Int,i), source_id, bus["vm"], vmin, vmax))
        end
    end
    sort!(df, [:year, :scenario, :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            keep_similar(x,y) = isapprox(x,y;atol=0.001) ? y : NaN
            sdf = select(gd[k], :hour, :id, :vm, [:vm,:vmin] => ByRow(keep_similar) => :dn, [:vm,:vmax] => ByRow(keep_similar) => :up)
            few_buses = length(unique(sdf.id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Voltage magnitude [p.u.]",
                xguide = "Time [periods]",
                framestyle = :grid,
                legend_position = few_buses ? :outertopright : :none,
            )
            hline!(plt, [1]; seriescolor=HSL(0,0,0), label=:none)
            gsd = groupby(sdf, :id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :vm, :dn, :up)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :vm;
                    seriestype = :stepmid,
                    fillrange = 1.0,
                    fillalpha = 0.05,
                    linewidth = few_buses ? 1.0 : 0.5,
                    seriescolor = few_buses ? :auto : HSL(0,0,0),
                    label = "bus_$(i.id)",
                )
                @df ssdf plot!(plt, [:dn :up];
                    seriestype = :stepmid,
                    seriescolor = [HSL(0,0.75,0.5) HSL(210,1,0.5)],
                    label = :none,
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Buses",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_gen(sol, data; <keyword arguments>)

Report the active power of generators along with their minimum and maximum active power.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_gen(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], id=Int[], source_id=String[], p=Float64[], pmin=Float64[], pmax=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (g, gen) in sol_nw["gen"]
            data_gen = data_nw["gen"][g]
            source_id = haskey(data_gen,"source_id") ? string(data_gen["source_id"][end]) : ""
            p = gen["pg"]
            pmin = data_gen["pmin"]
            pmax = data_gen["pmax"]
            push!(df, (h, s, y, parse(Int,g), source_id, p, pmin, pmax))
        end
    end
    sort!(df, [:year, :scenario, :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = select(gd[k], :hour, :id, :p, [:pmax,:p] => ByRow(-) => :ribbon_up, [:p,:pmin] => ByRow(-) => :ribbon_dn)
            few_generators = length(unique(sdf.id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Injected active power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_generators ? :outertopright : :none,
            )
            gsd = groupby(sdf, :id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :p, :ribbon_up, :ribbon_dn)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :hour, :p;
                    seriestype = :stepmid,
                    fillalpha = 0.05,
                    ribbon = (:ribbon_dn, :ribbon_up),
                    seriescolor = few_generators ? :auto : HSL(210,0.75,0.5),
                    linewidth = few_generators ? 1.0 : 0.5,
                    label = "gen_$(i.id)",
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Generators",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_load(sol, data; <keyword arguments>)

Report load variables.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_load(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], id=Int[], source_id=String[], flex=Bool[], pd=Float64[], pflex=Float64[], pshift_up=Float64[], pshift_down=Float64[], pred=Float64[], pcurt=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (i,load) in sol_nw["load"]
            data_load = data_nw["load"][i]
            source_id = string(data_load["source_id"][end])
            flex = Bool(round(Int,get(load,"flex",data_load["flex"])))
            pd = data_nw["load"][i]["pd"]
            push!(df, (h, s, y, parse(Int,i), source_id, flex, pd, load["pflex"], load["pshift_up"], load["pshift_down"], load["pred"], load["pcurt"]))
        end
    end
    sort!(df, [:year, :scenario, :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = select(gd[k], :hour, :id, :pflex, [:pd,:pflex] => ByRow(min) => :up, [:pd,:pflex] => ByRow(max) => :dn)
            few_loads = length(unique(sdf.id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Absorbed active power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_loads ? :outertopright : :none,
            )
            gsd = groupby(sdf, :id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :pflex, :up, :dn)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :pflex;
                    seriestype = :stepmid,
                    fillcolor = HSLA(210,1,0.5,0.1),
                    fillrange = :up,
                    seriescolor = HSLA(0,0,0,0),
                    linewidth = 0.0,
                    label = :none,
                )
                @df ssdf plot!(plt, :pflex;
                    seriestype = :stepmid,
                    fillcolor = HSLA(0,0.75,0.5,0.1),
                    fillrange = :dn,
                    seriescolor = HSLA(0,0,0,0),
                    linewidth = 0.0,
                    label = :none,
                )
                @df ssdf plot!(plt, :pflex;
                    seriestype = :stepmid,
                    seriescolor = few_loads ? :auto : HSL(0,0,0),
                    linewidth = 0.5,
                    label = "load_$(i.id)",
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Loads",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_load_summary(sol, data; <keyword arguments>)

Report aggregated load variables.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_load_summary(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], pd=Float64[], pflex=Float64[], pshift_up=Float64[], pshift_down=Float64[], pred=Float64[], pcurt=Float64[])
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        pd = sum(load["pd"] for load in values(data_nw["load"]))
        pflex = sum(load["pflex"] for load in values(sol_nw["load"]))
        pshift_up = sum(load["pshift_up"] for load in values(sol_nw["load"]))
        pshift_down = sum(load["pshift_down"] for load in values(sol_nw["load"]))
        pred = sum(load["pred"] for load in values(sol_nw["load"]))
        pcurt = sum(load["pcurt"] for load in values(sol_nw["load"]))
        push!(df, (h, s, y, pd, pflex, pshift_up, pshift_down, pred, pcurt))
    end

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            sdf = gd[k]
            plt = @df sdf groupedbar([:pshift_up :pshift_down :pred :pcurt :pflex-:pshift_up],
                bar_position = :stack,
                plot_title = "Aggregated load",
                plot_titlevspan = 0.07,
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Absorbed power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                bar_width = 1,
                linecolor = HSLA(0,0,1,0),
                legend_position = :bottomright,
                label = ["shift up" "shift down" "voluntary reduction" "curtailment" :none],
                seriescolor = [HSLA(210,1,0.67,0.75) HSLA(0,1,0.75,0.75) HSLA(0,0.67,0.5,0.75) HSLA(0,1,0.25,0.75) HSLA(0,0,0,0.1)],
            )
            @df sdf plot!(plt, :pd; label="reference demand", seriestype=:stepmid, linecolor=:black, linestyle=:dot)
            @df sdf plot!(plt, :pflex; label="absorbed power", seriestype=:stepmid, linecolor=:black)
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_storage(sol, data; <keyword arguments>)

Report energy and power of each storage.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_storage(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], component=String[], id=Int[], source_id=String[], energy=Float64[], energy_rating=Float64[], power=Float64[], power_min=Float64[], power_max=Float64[])

    # Read from `data` the initial energy of the first period, indexing it as hour 0.
    for n in _FP.nw_ids(dim; hour=1)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (i, st) in get(sol_nw, "storage", Dict{String,Any}())
            data_st = data_nw["storage"][i]
            source_id = string(data_st["source_id"][end])
            push!(df, (0, s, y, "storage", parse(Int,i), source_id, data_st["energy"], data_st["energy_rating"], NaN, NaN, NaN))
        end
        for (i, st) in get(sol_nw, "ne_storage", Dict{String,Any}())
            built = st["isbuilt"] > 0.5
            data_st = data_nw["ne_storage"][i]
            source_id = string(data_st["source_id"][end])
            push!(df, (0, s, y, "ne_storage", parse(Int,i), source_id, data_st["energy"]*built, data_st["energy_rating"]*built, NaN, NaN, NaN))
        end
    end
    # Read from `sol` power and final energy of each period.
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        for (i, st) in get(sol_nw, "storage", Dict{String,Any}())
            data_st = data_nw["storage"][i]
            source_id = string(data_st["source_id"][end])
            push!(df, (h, s, y, "storage", parse(Int,i), source_id, st["se"], data_st["energy_rating"], st["ps"], -data_st["discharge_rating"], data_st["charge_rating"]))
        end
        for (i, st) in get(sol_nw, "ne_storage", Dict{String,Any}())
            built = st["isbuilt"] > 0.5
            data_st = data_nw["ne_storage"][i]
            source_id = string(data_st["source_id"][end])
            push!(df, (h, s, y, "ne_storage", parse(Int,i), source_id, st["se_ne"]*built, data_st["energy_rating"]*built, st["ps_ne"], -data_st["discharge_rating"], data_st["charge_rating"]))
        end
    end
    sort!(df, [:year, :scenario, order(:component, rev=true), :id, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            # Energy plot
            sdf = select(gd[k], :hour, [:component,:id] => ByRow((c,i)->"$(c)_$i") => :comp_id, :energy, [:energy_rating,:energy] => ByRow(-) => :ribbon_up, :energy => :ribbon_dn)
            few_storage = length(unique(sdf.comp_id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Stored energy [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_storage ? :outertopright : :none,
            )
            gsd = groupby(sdf, :comp_id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :energy, :ribbon_up, :ribbon_dn)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :hour, :energy;
                    fillalpha = 0.05,
                    ribbon = (:ribbon_dn, :ribbon_up),
                    seriescolor = few_storage ? :auto : HSL(210,0.75,0.5),
                    linewidth = few_storage ? 1.0 : 0.5,
                    label = "$(i.comp_id)",
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Storage",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_energy_y$(k.year)_s$(k.scenario)$ext"))

            # Power plot
            sdf = select(gd[k], :hour, [:component,:id] => ByRow((c,i)->"$(c)_$i") => :comp_id, :power, [:power_max,:power] => ByRow(-) => :ribbon_up, [:power,:power_min] => ByRow(-) => :ribbon_dn)
            few_storage = length(unique(sdf.comp_id)) ≤ 24
            plt = Plots.plot(
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Absorbed power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = few_storage ? :outertopright : :none,
            )
            gsd = groupby(sdf, :comp_id)
            for i in keys(gsd)
                ssdf = select(gsd[i], :hour, :power, :ribbon_up, :ribbon_dn)
                sort!(ssdf, :hour)
                @df ssdf plot!(plt, :hour, :power;
                    fillalpha = 0.05,
                    ribbon = (:ribbon_dn, :ribbon_up),
                    seriestype = :stepmid,
                    seriescolor = few_storage ? :auto : HSL(210,0.75,0.5),
                    linewidth = few_storage ? 1.0 : 0.5,
                    label = "$(i.comp_id)",
                )
            end
            # Needed to add below data after the for loop because otherwise an unwanted second axes frame is rendered under the plot_title.
            plot!(plt,
                plot_title = "Storage",
                plot_titlevspan = 0.07,
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_power_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end

"""
    sol_report_storage_summary(sol, data; <keyword arguments>)

Report aggregated energy and power of connected storage.

Return a DataFrame; optionally write a CSV table and a plot.

# Arguments
- `sol::Dict{String,Any}`: the solution Dict contained in the result Dict of a FlexPlan
  optimization problem.
- `data::Dict{String,Any}`: the multinetwork data Dict used for the same FlexPlan
  optimization problem.
- `out_dir::String=pwd()`: directory for output files.
- `table::String=""`: if not empty, output a CSV table to `table` file.
- `plot::String=""`: if not empty, output a plot to `plot` file; file type is based on
  `plot` extension.
"""
function sol_report_storage_summary(sol::Dict{String,Any}, data::Dict{String,Any}; out_dir::String=pwd(), table::String="", plot::String="")
    _FP.require_dim(data, :hour, :scenario, :year)
    dim = data["dim"]

    df = DataFrame(hour=Int[], scenario=Int[], year=Int[], energy=Float64[], energy_rating=Float64[], power=Float64[], power_min=Float64[], power_max=Float64[])

    # Read from `data` the initial energy of the first period, indexing it as hour 0.
    for n in _FP.nw_ids(dim; hour=1)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        energy = sum(st["energy"] for st in values(get(data_nw,"storage",Dict())) if st["status"]>0; init=0.0) + sum(data_nw["ne_storage"][s]["energy"] for (s,st) in get(sol_nw,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
        energy_rating = sum(st["energy_rating"] for st in values(get(data_nw,"storage",Dict())) if st["status"]>0; init=0.0) + sum(data_nw["ne_storage"][s]["energy_rating"] for (s,st) in get(sol_nw,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
        push!(df, (0, s, y, energy, energy_rating, NaN, NaN, NaN))
    end
    # Read from `sol` power and final energy of each period.
    for n in _FP.nw_ids(dim)
        sol_nw = sol["nw"]["$n"]
        data_nw = data["nw"]["$n"]
        h = _FP.coord(dim, n, :hour)
        s = _FP.coord(dim, n, :scenario)
        y = _FP.coord(dim, n, :year)
        energy = sum(st["se"] for (s,st) in get(sol_nw,"storage",Dict()) if data_nw["storage"][s]["status"]>0; init=0.0) + sum(st["se_ne"] for st in values(get(sol_nw,"ne_storage",Dict())) if st["isbuilt"]>0.5; init=0.0)
        energy_rating = sum(st["energy_rating"] for st in values(get(data_nw,"storage",Dict())) if st["status"]>0; init=0.0) + sum(data_nw["ne_storage"][s]["energy_rating"] for (s,st) in get(sol_nw,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
        power = sum(st["ps"] for (s,st) in get(sol_nw,"storage",Dict()) if data_nw["storage"][s]["status"]>0; init=0.0) + sum(st["ps_ne"] for st in values(get(sol_nw,"ne_storage",Dict())) if st["isbuilt"]>0.5; init=0.0)
        power_min = -sum(st["discharge_rating"] for (s,st) in get(data_nw,"storage",Dict()) if st["status"]>0; init=0.0) - sum(data_nw["ne_storage"][s]["discharge_rating"] for (s,st) in get(sol_nw,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
        power_max = sum(st["charge_rating"] for (s,st) in get(data_nw,"storage",Dict()) if st["status"]>0; init=0.0) + sum(data_nw["ne_storage"][s]["charge_rating"] for (s,st) in get(sol_nw,"ne_storage",Dict()) if st["isbuilt"]>0.5; init=0.0)
        push!(df, (h, s, y, energy, energy_rating, power, power_min, power_max))
    end
    sort!(df, [:year, :scenario, :hour])

    if !isempty(table)
        CSV.write(joinpath(out_dir,table), df)
    end

    if !isempty(plot)
        gd = groupby(df, [:scenario, :year])
        for k in keys(gd)
            # Energy plot
            sdf = select(gd[k], :hour, :energy, [:energy_rating,:energy] => ByRow(-) => :ribbon_up, :energy => :ribbon_dn)
            sort!(sdf, :hour)
            plt = @df sdf Plots.plot(:hour, :energy;
                plot_title = "Aggregated storage",
                plot_titlevspan = 0.07,
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Stored energy [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = :none,
                fillalpha = 0.1,
                ribbon = (:ribbon_dn, :ribbon_up),
                seriescolor = HSL(210,0.75,0.5),
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_energy_y$(k.year)_s$(k.scenario)$ext"))

            # Power plot
            sdf = select(gd[k], :hour, :power, [:power_max,:power] => ByRow(-) => :ribbon_up, [:power,:power_min] => ByRow(-) => :ribbon_dn)
            sort!(sdf, :hour)
            plt = @df sdf Plots.plot(:hour, :power;
                plot_title = "Aggregated storage",
                plot_titlevspan = 0.07,
                title = "scenario $(k.scenario), year $(k.year)",
                titlefontsize = 8,
                yguide = "Absorbed power [p.u.]",
                xguide = "Time [periods]",
                framestyle = :zerolines,
                legend_position = :none,
                seriestype = :stepmid,
                fillalpha = 0.1,
                ribbon = (:ribbon_dn, :ribbon_up),
                seriescolor = HSL(210,0.75,0.5),
            )
            name, ext = splitext(plot)
            savefig(plt, joinpath(out_dir,"$(name)_power_y$(k.year)_s$(k.scenario)$ext"))
        end
    end

    return df
end
