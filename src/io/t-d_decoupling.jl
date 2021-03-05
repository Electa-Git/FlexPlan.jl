# Data analysis and plotting related to decoupling of transmission and distribution

using Printf
using DataFrames
using StatsPlots

function report_dist_candidates_pcc_power(
        dist_candidates::Dict{String,Any},
        out_dir::String;
        filename::String = "pcc_power",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates))),
        report_deviation::Bool = true,
        report_flex_band::Bool = true,
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
    mkpath(out_dir)
    periods = parse.(Int,first(values(dist_candidates))["ids"]["nw"])
    pcc_power = DataFrame()
    pcc_power.period = periods
    for cand_id in candidate_ids
        res = dist_candidates[cand_id]["result"]
        pcc_power[!,"$(cand_id)_import"] = [res["import"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
        if haskey(res, "base")
            pcc_power[!,"$(cand_id)_base"] = [res["base"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
        end
        pcc_power[!,"$(cand_id)_export"] = [res["export"]["solution"]["nw"]["$t"]["td_coupling"]["p"] for t in periods]
    end
    CSV.write(normpath(out_dir,"$filename.csv"), pcc_power)
    if plot
        plt = @df pcc_power Plots.plot(:period, cols(2:ncol(pcc_power));
            title  = "Power exchange at PCC",
            ylabel = "Imported power [MW]",
            xlabel = "Period",
            legend = :outertopright,
            plot_kwargs...
        )
        savefig(plt, normpath(out_dir,"$filename.$plot_ext"))
    end
    if report_deviation
        pcc_deviation = DataFrame()
        pcc_deviation.period = pcc_power.period
        for cand_id in candidate_ids
            res = dist_candidates[cand_id]["result"]
            if haskey(res, "base")
                pcc_deviation["$(cand_id)_import"] = pcc_power["$(cand_id)_import"] - pcc_power["$(cand_id)_base"]
                pcc_deviation["$(cand_id)_export"] = pcc_power["$(cand_id)_export"] - pcc_power["$(cand_id)_base"]
            end
        end
        CSV.write(normpath(out_dir,"$(filename)_deviation.csv"), pcc_deviation)
        if plot
            plt = @df pcc_deviation Plots.plot(:period, cols(2:ncol(pcc_deviation));
                title  = "Difference in power exchange at PCC w.r.t. base case",
                ylabel = "Power [MW]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_deviation.$plot_ext"))
        end
    end
    if report_flex_band
        pcc_flex_band = DataFrame()
        pcc_flex_band.period = pcc_power.period
        for cand_id in candidate_ids
            pcc_flex_band["$(cand_id)"] = pcc_power["$(cand_id)_import"] - pcc_power["$(cand_id)_export"]
        end
        CSV.write(normpath(out_dir,"$(filename)_flex_band.csv"), pcc_flex_band)
        if plot
            plt = @df pcc_flex_band Plots.plot(:period, cols(2:ncol(pcc_flex_band));
                title  = "Flexibility band at PCC",
                ylabel = "Power [MW]",
                xlabel = "Period",
                legend = :outertopright,
                ylims  = (0.0, Inf),
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_flex_band.$plot_ext"))
        end
    end
end

function report_dist_candidates_branch(
        dist_candidates::Dict{String,Any},
        out_dir::String,
        sn_data::Dict{String,Any};
        filename::String = "branch",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates))),
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
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
    branch = DataFrame(candidate = String[], result = String[], period = Int[], type = String[], id = Int[], p = Float64[], q = Float64[], p_rel = Float64[])
    for cand_id in candidate_ids
        for (res_id, res) in dist_candidates[cand_id]["result"]
            for (n, nw) in res["solution"]["nw"]
                for comp in ("branch", "ne_branch")
                    for (b, br) in get(nw, comp, Dict{String,Any}())
                        rated = sn_data[comp][b]["rate_a"]
                        p = br["pf"]
                        q = br["qf"]
                        p_rel = _calc_p_rel(p, q, rated)
                        push!(branch, (cand_id, res_id, parse(Int,n), comp, parse(Int, b), p, q, p_rel))
                    end
                end
            end
        end
    end
    sort!(branch, 1:5)
    CSV.write(normpath(out_dir,"$(filename).csv"), branch)

    if plot
        branch.cand_res = branch.candidate .* "_" .* branch.result
        branch.b = branch.type .* "_" .* string.(branch.id)
        branch_prel = DataFrames.unstack(branch, [:cand_res, :period], :b, :p_rel)
        for cand_res_branch in DataFrames.groupby(branch_prel, :cand_res)
            cand_res = cand_res_branch[1, :cand_res]
            plt = @df cand_res_branch Plots.plot(:period, cols(3:ncol(branch_prel));
                title  = "Relative active power of branches, $cand_res",
                xlabel = "Period",
                legend = :outertopright,
                legendfontsize = 5,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_$(cand_res).$plot_ext"))
        end
    end
end

function report_dist_candidates_storage(
        dist_candidates::Dict{String,Any},
        out_dir::String;
        filename::String = "storage",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates))),
        plot::Bool = true,
        plot_ext::String = "pdf",
        plot_kwargs...
    )
    mkpath(out_dir)
    storage_power = DataFrame(candidate = String[], result = String[], period = Int[], type = String[], id = Int[], p = Float64[])
    for cand_id in candidate_ids
        for (res_id, res) in dist_candidates[cand_id]["result"]
            for (n, nw) in res["solution"]["nw"]
                for (comp, p_key) in ("storage" => "ps", "ne_storage" => "ps_ne")
                    for (s, st) in get(nw, comp, Dict{String,Any}())
                        push!(storage_power, (cand_id, res_id, parse(Int,n), comp, parse(Int, s), st[p_key]))
                    end
                end
            end
        end
    end
    sort!(storage_power, 1:5)
    if nrow(storage_power) > 0
        CSV.write(normpath(out_dir,"$(filename)_power.csv"), storage_power)
        storage_power.cand_res = storage_power.candidate .* "_" .* storage_power.result
        storage_power.s = storage_power.type .* "_" .* string.(storage_power.id)
        storage_p = DataFrames.unstack(storage_power, [:s, :period], :cand_res, :p)
        for a_storage in DataFrames.groupby(storage_p, :s)
            s = a_storage[1, :s]
            plt = @df a_storage Plots.plot(:period, cols(3:ncol(storage_p));
                title  = "$s",
                ylabel = "Absorbed power [MW]",
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
                ylabel = "Absorbed power [MW]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_power_total.$plot_ext"))
        end
    end

    storage_energy = DataFrame(candidate = String[], result = String[], period = Int[], type = String[], id = Int[], e = Float64[])
    for cand_id in candidate_ids
        for (res_id, res) in dist_candidates[cand_id]["result"]
            if res_id == "base"
                for (n, nw) in res["solution"]["nw"]
                    for (comp, e_key) in ("storage" => "se", "ne_storage" => "se_ne")
                        for (s, st) in get(nw, comp, Dict{String,Any}())
                            push!(storage_energy, (cand_id, res_id, parse(Int,n), comp, parse(Int, s), st[e_key]))
                        end
                    end
                end
            end
        end
    end
    sort!(storage_energy, 1:5)
    if nrow(storage_energy) > 0
        CSV.write(normpath(out_dir,"$(filename)_energy.csv"), storage_energy)
        storage_energy.cand_res = storage_energy.candidate .* "_" .* storage_energy.result
        storage_energy.s = storage_energy.type .* "_" .* string.(storage_energy.id)
        storage_e = DataFrames.unstack(storage_energy, [:s, :period], :cand_res, :e)
        for a_storage in DataFrames.groupby(storage_e, :s)
            s = a_storage[1, :s]
            plt = @df a_storage Plots.plot(:period, cols(3:ncol(storage_e));
                title  = "$s",
                ylabel = "Stored energy [MWh]",
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
                ylabel = "Stored energy [MWh]",
                xlabel = "Period",
                legend = :outertopright,
                plot_kwargs...
            )
            savefig(plt, normpath(out_dir,"$(filename)_energy_total.$plot_ext"))
        end
    end
end

function report_dist_candidates_investment(
        dist_candidates::Dict{String,Any},
        out_dir::String;
        filename::String = "investment",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates)))
    )
    mkpath(out_dir)
    investment = DataFrame(candidate=String[], component=String[], id=Int[], built=Bool[])
    for (cand_id, candidate) in dist_candidates
        for (comp_name, component) in candidate["investment"]
            for (comp_id, comp_activation) in component
                push!(investment, (cand_id, comp_name, parse(Int,comp_id), comp_activation))
            end
        end
    end
    investments = DataFrames.unstack(investment, :candidate, :built)
    select!(investments, ["component", "id", candidate_ids...]) # To change the order of columns
    CSV.write(normpath(out_dir,"$filename.csv"), investments)
end

function report_dist_candidates_cost(
        dist_candidates::Dict{String,Any},
        out_dir::String;
        filename::String = "cost",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates)))
    )
    mkpath(out_dir)
    cost = DataFrame(candidate=String[], cost=Float64[])
    for cand_id in candidate_ids
        push!(cost, (cand_id, dist_candidates[cand_id]["cost"]))
    end
    CSV.write(normpath(out_dir,"$filename.csv"), cost)
end

function report_dist_candidates_nw_summary(
        dist_candidates::Dict{String,Any},
        out_dir::String;
        subdir::String = "nw_summary",
        candidate_ids::Vector{String} = sort(collect(keys(dist_candidates)))
    )
    for cand_id in candidate_ids
        for (res_id, res) in dist_candidates[cand_id]["result"]
            summary_dir = mkpath(normpath(out_dir, subdir, cand_id, res_id))
            for (n, nw) in res["solution"]["nw"]
                file = normpath(summary_dir,"$(@sprintf("%04i",parse(Int,n))).txt")
                open(file, "w") do io
                    _PM.summary(io, nw)
                end
            end
        end
    end
end
