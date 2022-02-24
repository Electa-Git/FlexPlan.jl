# Data analysis and plotting related to decoupling of transmission and distribution

using Printf
using DataFrames
using StatsPlots

function report_flex_pcc_power(
        flex_result::Dict{String,Any},
        out_dir::String;
        filename::String = "pcc_power",
        report_deviation::Bool = true,
        report_flex_band::Bool = true,
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
    mkpath(out_dir)
    res = flex_result["result"]
    periods = parse.(Int,flex_result["ids"]["nw"])
    pcc_power = DataFrame()
    pcc_power.period = periods
    pcc_power.up     = [res["up"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
    pcc_power.base   = [res["base"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
    pcc_power.down   = [res["down"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
    CSV.write(normpath(out_dir,"$filename.csv"), pcc_power)
    if plot
        plt = @df pcc_power Plots.plot(:period, cols(2:ncol(pcc_power));
            title  = "Power exchange at PCC",
            ylabel = "Imported power [p.u.]",
            xlabel = "Period",
            legend = :outertopright,
            plot_kwargs...
        )
        savefig(plt, normpath(out_dir,"$filename.$plot_ext"))
    end
    if report_deviation
        pcc_deviation = DataFrame()
        pcc_deviation.period = periods
        pcc_deviation.up     = pcc_power.up - pcc_power.base
        pcc_deviation.down   = pcc_power.down - pcc_power.base
        CSV.write(normpath(out_dir,"$(filename)_deviation.csv"), pcc_deviation)
        if plot
            plt = @df pcc_deviation Plots.plot(:period, cols(2:ncol(pcc_deviation));
                title  = "Difference in power exchange at PCC w.r.t. base case",
                ylabel = "Power [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_deviation.$plot_ext"))
        end
    end
    if report_flex_band
        pcc_flex_band = DataFrame()
        pcc_flex_band.period = periods
        pcc_flex_band.band   = pcc_power.up - pcc_power.down
        CSV.write(normpath(out_dir,"$(filename)_flex_band.csv"), pcc_flex_band)
        if plot
            plt = @df pcc_flex_band Plots.plot(:period, cols(2:ncol(pcc_flex_band));
                title  = "Flexibility band at PCC",
                ylabel = "Power [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                ylims  = (0.0, Inf),
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_flex_band.$plot_ext"))
        end
    end
end

function report_flex_branch(
        flex_result::Dict{String,Any},
        out_dir::String,
        mn_data::Dict{String,Any};
        filename::String = "branch",
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
    sn_data = mn_data["nw"]["$(first(_FP.nw_ids(mn_data; hour=1, scenario=1)))"]
    function _calc_p_rel(p, q, rated)
        p = abs(p)
        q = abs(q)
        if q <= sin(π/8) * rated
            return p / (cos(π/8)*rated)
        else
            return p / ((sin(π/8)+cos(π/8))*rated - q)
        end
    end
    mkpath(out_dir)
    branch = DataFrame(result = String[], period = Int[], type = String[], id = Int[], p = Float64[], q = Float64[], p_rel = Float64[])
    for (res_id, res) in flex_result["result"]
        for (n, nw) in res["solution"]["nw"]
            for comp in ("branch", "ne_branch")
                for (b, br) in get(nw, comp, Dict{String,Any}())
                    rated = sn_data[comp][b]["rate_a"]
                    p = br["pf"]
                    q = br["qf"]
                    p_rel = _calc_p_rel(p, q, rated)
                    push!(branch, (res_id, parse(Int,n), comp, parse(Int, b), p, q, p_rel))
                end
            end
        end
    end
    sort!(branch, 1:4)
    CSV.write(normpath(out_dir,"$(filename).csv"), branch)
    if plot
        branch.b = branch.type .* "_" .* string.(branch.id)
        branch_prel = DataFrames.unstack(branch, [:result, :period], :b, :p_rel)
        for result_branch in DataFrames.groupby(branch_prel, :result)
            res = result_branch[1, :result]
            plt = @df result_branch Plots.plot(:period, cols(3:ncol(branch_prel));
                title  = "Relative active power of branches, $res",
                xlabel = "Period",
                legend = :outertopright,
                legendfontsize = 5,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_$(res).$plot_ext"))
        end
    end
end

function report_flex_storage(
        flex_result::Dict{String,Any},
        out_dir::String;
        filename::String = "storage",
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
    mkpath(out_dir)
    storage_power = DataFrame(result = String[], period = Int[], type = String[], id = Int[], p = Float64[])
    for (res_id, res) in flex_result["result"]
        for (n, nw) in res["solution"]["nw"]
            for (comp, p_key) in ("storage" => "ps", "ne_storage" => "ps_ne")
                for (s, st) in get(nw, comp, Dict{String,Any}())
                    push!(storage_power, (res_id, parse(Int,n), comp, parse(Int, s), st[p_key]))
                end
            end
        end
    end
    sort!(storage_power, 1:4)
    if nrow(storage_power) > 0
        CSV.write(normpath(out_dir,"$(filename)_power.csv"), storage_power)
        storage_power.s = storage_power.type .* "_" .* string.(storage_power.id)
        storage_p = DataFrames.unstack(storage_power, [:s, :period], :result, :p)
        for a_storage in DataFrames.groupby(storage_p, :s)
            s = a_storage[1, :s]
            plt = @df a_storage Plots.plot(:period, cols(3:ncol(storage_p));
                title  = "$s",
                ylabel = "Absorbed power [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_power_$(s).$plot_ext"))
        end

        storage_power_total = combine(DataFrames.groupby(storage_p, :period), names(storage_p)[3:end].=>sum.=>names(storage_p)[3:end])
        CSV.write(normpath(out_dir,"$(filename)_power_total.csv"), storage_power_total)
        if plot
            plt = @df storage_power_total Plots.plot(:period, cols(2:ncol(storage_power_total));
                title  = "Total storage",
                ylabel = "Absorbed power [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_power_total.$plot_ext"))
        end
    end

    storage_energy = DataFrame(result = String[], period = Int[], type = String[], id = Int[], e = Float64[])
    for (res_id, res) in flex_result["result"]
        if res_id == "base"
            for (n, nw) in res["solution"]["nw"]
                for (comp, e_key) in ("storage" => "se", "ne_storage" => "se_ne")
                    for (s, st) in get(nw, comp, Dict{String,Any}())
                        push!(storage_energy, (res_id, parse(Int,n), comp, parse(Int, s), st[e_key]))
                    end
                end
            end
        end
    end
    sort!(storage_energy, 1:4)
    if nrow(storage_energy) > 0
        CSV.write(normpath(out_dir,"$(filename)_energy.csv"), storage_energy)
        storage_energy.s = storage_energy.type .* "_" .* string.(storage_energy.id)
        storage_e = DataFrames.unstack(storage_energy, [:s, :period], :result, :e)
        for a_storage in DataFrames.groupby(storage_e, :s)
            s = a_storage[1, :s]
            plt = @df a_storage Plots.plot(:period, cols(3:ncol(storage_e));
                title  = "$s",
                ylabel = "Stored energy [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_energy_$(s).$plot_ext"))
        end

        storage_energy_total = combine(DataFrames.groupby(storage_e, :period), names(storage_e)[3:end].=>sum.=>names(storage_e)[3:end])
        CSV.write(normpath(out_dir,"$(filename)_energy_total.csv"), storage_energy_total)
        if plot
            plt = @df storage_energy_total Plots.plot(:period, cols(2:ncol(storage_energy_total));
                title  = "Total storage",
                ylabel = "Stored energy [p.u.]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_energy_total.$plot_ext"))
        end
    end
end

function report_flex_investment(
        flex_result::Dict{String,Any},
        out_dir::String;
        filename::String = "investment",
    )
    mkpath(out_dir)
    investment = DataFrame(component=String[], id=Int[], built=Bool[])
    for (comp_name, component) in flex_result["investment"]
        for (comp_id, comp_activation) in component
            push!(investment, (comp_name, parse(Int,comp_id), comp_activation))
        end
    end
    sort!(investment)
    CSV.write(normpath(out_dir,"$filename.csv"), investment)
end

function report_flex_nw_summary(
        flex_result::Dict{String,Any},
        out_dir::String;
        subdir::String = "nw_summary",
    )
    for (res_id, res) in flex_result["result"]
        summary_dir = mkpath(normpath(out_dir, subdir, res_id))
        for (n, nw) in res["solution"]["nw"]
            file = normpath(summary_dir,"$(@sprintf("%04i",parse(Int,n))).txt")
            open(file, "w") do io
                _PM.summary(io, nw)
            end
        end
    end
end
