using Plots
using DataStructures

function plot_profile_data(extradata, number_of_hours, solution = Dict(), res_gen_ids = nothing)
    # Plots load and generation profile data at grid level.
    # See test_italian_case.jl for an example of how to use.
    # Does not support stochastic formulation yet.

    hours = [1:number_of_hours]

    # compute total load in the system at each hour
    total_load_pu = zeros(number_of_hours)
    for (load_id,load) in extradata["load"]
        for h in 1:number_of_hours
            total_load_pu[h] += load["pd"][h]
        end
    end
    p = plot(hours,total_load_pu,label="Total load (p.u.)",xlabel="Time (h)",
        ylabel="Load/generation (p.u.)",xlim=(0,number_of_hours))

    # compute total generation capacity of the system at each hour
    tot_gen_cap_pu = zeros(number_of_hours)
    for (gen_id,gen) in extradata["gen"]
        for h in 1:number_of_hours
            tot_gen_cap_pu[h] += gen["pmax"][h]
        end
    end
    plot!(hours,tot_gen_cap_pu,label="Total generation capacity (p.u.)")

    # compute actual total generation at each hour if solution provided
    if haskey(solution,"nw")
        actual_gen_pu = zeros(number_of_hours)

        for (nw_id,nw) in solution["nw"]
            h = parse(Int,nw_id)
            for (gen_id,gen) in nw["gen"]
                actual_gen_pu[h] += gen["pg"]
            end
        end
        plot!(hours,actual_gen_pu,label="Actual generation (p.u.)")
    end


    # compute RES and traditional generation capacity at each hour if res_gen_ids != nothing
    if !isnothing(res_gen_ids)
        tot_res_cap_pu = zeros(number_of_hours)
        tot_trad_cap_pu = zeros(number_of_hours)

        for (gen_id,gen) in extradata["gen"]
            for h in 1:number_of_hours
                if gen_id in res_gen_ids
                    tot_res_cap_pu[h] += gen["pmax"][h]
                else
                    tot_trad_cap_pu[h] += gen["pmax"][h]
                end
            end
        end
        plot!(hours,tot_trad_cap_pu,label="Trad. generation capacity (p.u.)")
        plot!(hours,tot_res_cap_pu,label="RES generation capacity (p.u.)")
    end

    return p
end

function plot_storage_data(data,solution)
    # Plots storage charge/discharge power and energy level at each
    # time step and for each existing and candidate storage asset.
    # See test_italian_case.jl for an example of how to use.
    # Does not support stochastic formulation yet.

    nws = solution["nw"]
    if haskey(nws["1"],"storage")
        n_st = length(nws["1"]["storage"]) #number of existing storage assets
    else
        n_st = 0
    end

    if haskey(nws["1"],"ne_storage")
        n_st_ne = length(nws["1"]["ne_storage"]) # number of candidate storage assets
    else
        n_st_ne = 0
    end

    number_of_hours = length(nws)
    t = [1:number_of_hours;]
    st_power = zeros((n_st+n_st_ne,number_of_hours)) #storage power (charge/discharge) at each time step
    st_energy = zeros((n_st+n_st_ne,number_of_hours)) #stoarge energy level at each time step

    for (hour,nw) in nws
        h = parse(Int,hour)
        # existing storage assets
        if haskey(nw,"storage")
            for (index,st) in nw["storage"]
                i = parse(Int,index)
                if st["sc"] > 0 # charge taken as positive power
                    st_power[i,h] = st["sc"]
                    if st["sd"] != 0 println("storage charge and discharge not exclsuive") end
                elseif st["sd"] > 0 # discharge taken as negative power
                    st_power[i,h] = -st["sd"]
                    if st["sc"] != 0 println("storage charge and discharge not exclsuive") end
                end
                # energy level: divide storage energy by energy rating
                st_energy[i,h] = st["se"]/data["storage"][index]["energy_rating"]
            end
        end
        # candidate storage assets
        if haskey(nw,"ne_storage")
            for (index_ne,st_ne) in nw["ne_storage"]
                if st_ne["isbuilt"] == 1
                    i = parse(Int,index_ne)
                    if st_ne["sc_ne"] > 0 # charge taken as positive power
                        st_power[i+n_st,h] = st_ne["sc_ne"]
                    elseif st_ne["sd_ne"] > 0 # discharge taken as negative power
                        st_power[i+n_st,h] = -st_ne["sd_ne"]
                    end
                    # energy level: divide storage energy by energy rating
                    st_energy[i+n_st,h] = st_ne["se_ne"]/data["ne_storage"][index_ne]["energy_rating"]
                end
            end
        end
    end

    # remove rows of not built storage assets
    index = [1:n_st;]
    for (ne_st_ind,ne_st) in nws["1"]["ne_storage"]
        if ne_st["isbuilt"] == 1
            push!(index,n_st + parse(Int,ne_st_ind))
        end
    end
    st_power = st_power[index,:]
    st_energy = st_energy[index,:]

    # labels for plottingg
    labels1 = ["Storage $i" for i in 1:n_st]
    labels2 = ["Candidate storage $(ne_st_ind)" for (ne_st_ind,ne_st) in nws["1"]["ne_storage"] if ne_st["isbuilt"] == 1]
    labels = append!(labels1,labels2)
    labels = reshape(labels, 1, :)

    p1 = bar(t,st_power',bar_position = :dodge,label=labels,xlabel="Time (h)",
            ylabel="Storage charge/dicharge (p.u.)",xlim=(0,number_of_hours))
    p2 = bar(t,st_energy',bar_position = :dodge,xlabel="Time (h)",label=labels,
            ylabel="Energy level",xlim=(0,number_of_hours))
    return p1,p2
end


"""
    plot_branch_flow(results,i_branch,input_data)

Plot time series for power flow on a branch no. 'i_branch' in the network
in the multi-period OPF solution 'results'. If input data Dict 'input_data'
is provided, the branch flow is compared with the branch power ratings in
the plots. If 'i_branch' is _not_ provided, all branches are plotted.
The optional input argument 'branch_type' specifies which type of branch
flow is tested for, either "branch" (i.e. AC branches; default), "branchdc"
(DC branches), "ne_branch" (candidate AC branch), or "branchdc_ne" 
(candidate DC branches).
"""
function plot_branch_flow(results, i_branch_plot=[], input_data=[], branch_type="branch")

    # Handle different types of branches (different dictionary keys are used for
    # different types of dictionaries...)
    if branch_type == "branch"
        flow_key = "pt"    
        rate_key = "rate_a"    
    elseif branch_type == "branchdc"
        flow_key = "pt"    
        rate_key = "rateA"    
    elseif branch_type == "ne_branch"        
        flow_key = "p_ne_to"
        built_key = "built"
        rate_key = "rate_a"
    elseif branch_type == "branchdc_ne"
        flow_key = "pt"
        built_key = "isbuilt"
        rate_key = "rateA"
    else
        error("Input argument 'branch type' needs to be 'branch', 'branchdc', 'ne_branch', or branchdc_ne")
    end

    # Input argument checks
    if haskey(results, "solution")
        if haskey(results["solution"], "nw")
            sol_1 = results["solution"]["nw"]["1"]
        else
            error("Input argument results has to be the result of a multi-period OPF problem")
        end
    end
    if !haskey(results["solution"]["nw"]["1"][branch_type], string(i_branch_plot))
        error(string("Does not find #", i_branch_plot, " of ", branch_type))
    end
    if !isempty(i_branch_plot)
        if branch_type == "ne_branch" || branch_type == "branchdc_ne"
            if results["solution"]["nw"]["1"][branch_type][string(i_branch_plot)][built_key] != 1
                println(string("Warning: ", branch_type, " #", string(i_branch_plot), " is not built"))
            end
        end
    end

    # Number of branches in network
    n_branches = length(sol_1[branch_type])
    
    # Extract branch power flow rating (rate_a)
    if !isempty(input_data)
        rate_a = zeros(n_branches, 1)
        for i_branch = 1:n_branches
            rate_a[i_branch] = data[branch_type][string(i_branch)][rate_key]
        end
    else
        rate_a = []
    end

    # Find number and set of time steps
    n_time_steps = length(results["solution"]["nw"])
    t_vec = [1:n_time_steps]

    # Extract power flow pt (at the to-end of the branch)
    pt = zeros(n_time_steps, n_branches)        
    for i_branch = 1:n_branches
        for t = 1:n_time_steps
            pt[t,i_branch] = results["solution"]["nw"][string(t)][branch_type][string(i_branch)][flow_key]           
        end
    end

    # Plotting branch power flows
    p = plot(xlabel="Time step", ylabel="Power flow (p.u.)")
    if !isempty(i_branch_plot)
        pt_plot = pt[:,i_branch_plot]
        plot!(p, t_vec, pt_plot, label=string("Flow on ", branch_type, " #", i_branch_plot), color=:red)
        if !isempty(rate_a)
            # Plot branch power rating (if provided)
            rate_a_plot = ones(n_time_steps, 1) * rate_a[i_branch_plot,1]
            plot!(p, t_vec, rate_a_plot, label=string("Rating of ", branch_type, " #", i_branch_plot), color=:black, line=:dash)
            plot!(p, t_vec, -rate_a_plot, label=string("Rating of ", branch_type, " #", i_branch_plot), color=:black, line=:dash)
        end
    else
        # Plot power flow for all branches if branch not specified
        plot!(p, pt)
    end

    return p
end


"""
    plot_flex_demand(results,i_load,input_data,input_extra_data)

    Plot time series for demand shifted and/or curtailed for flexible demand 
    element 'i_load_plot' in the network in the multi-period OPF solution 
    'results'. The input argument 'input_data' are the static network input data
    for the case whereas the input argument 'input_extradata' contains the 
    (reference) load demand time series for the case.
"""
function plot_flex_demand(results, i_load_plot, input_data, input_extra_data)

    # Input argument checks
    if !haskey(results["solution"], "multinetwork") || !results["solution"]["multinetwork"]
        error("Input argument results has to be the result of a multi-period OPF problem")
    end            
    if !haskey(input_extra_data["load"], string(i_load_plot)) 
        error(string("There does not exist a load at bus ", i_load_plot))
    end
    isflex = input_data["load"][string(i_load_plot)]["flex"]
    if isflex == 0
        println(string("Warning: Load at bus ", i_load_plot, " is not flexible"))
    end

    # Find number and set of time steps
    n_time_steps = length(results["solution"]["nw"])
    t_vec = [1:n_time_steps]
    
    pd = zeros(n_time_steps, 1)             # Load demand at bus (input data)      
    pflex = zeros(n_time_steps, 1)          # Actual (flexible) load demand at bus    
    pshift_down = zeros(n_time_steps, 1)    # Downwards load shifting
    pshift_up = zeros(n_time_steps, 1)      # Upwards demand shifting
    pnce = zeros(n_time_steps, 1)           # Not consumed energy
    pcurt = zeros(n_time_steps, 1)          # Demand curtailment
    
    # Extract demand-related variables from the solution
    for t = 1:n_time_steps
        pd[t,1] = input_extra_data["load"][string(i_load_plot)]["pd"][t]          
        pflex[t,1] = results["solution"]["nw"][string(t)]["load"][string(i_load_plot)]["pflex"]           
        pshift_down[t,1] = results["solution"]["nw"][string(t)]["load"][string(i_load_plot)]["pshift_down"]           
        pshift_up[t,1] = results["solution"]["nw"][string(t)]["load"][string(i_load_plot)]["pshift_up"]           
        pnce[t,1] = results["solution"]["nw"][string(t)]["load"][string(i_load_plot)]["pnce"]           
        pcurt[t,1] = results["solution"]["nw"][string(t)]["load"][string(i_load_plot)]["pcurt"]           
    end
    
    # Plotting demand variables
    p = plot(xlabel="Time step", ylabel="Load (p.u.)")
    
    plot!(p, t_vec, pd, label=string("Reference demand"))
    
    # If no demand shifting or curtailment, this should plot the same as the reference demand above
    plot!(p, t_vec, pflex, label=string("Actual (flexible) demand"))
    
    #  If no demand shifting or curtailment, this should all be zeros
    plot!(p, t_vec, pshift_down, label=string("Downwards load shifting"))
    plot!(p, t_vec, pshift_up, label=string("Upwards demand shifting"))
    plot!(p, t_vec, pnce, label=string("Not consumed energy"))
    plot!(p, t_vec, pcurt, label=string("Demand curtailment"))    

    return p
end


function plot_res(res::Dict, utype::String, unit::String, var::String; kwargs...)

    var_table = get_res(res, utype, unit)
    
    time = select(var_table, :time)
    val = select(var_table, Symbol(var))

    plot(time, val; kwargs...)
end

function plot_res!(res::Dict, utype::String, unit::String, var::String; kwargs...)

    var_table = get_res(res, utype, unit)
    
    time = select(var_table, :time)
    val = select(var_table, Symbol(var))

    plot!(time, val, label=var; kwargs...)
end

function plot_res(res::Dict, utype::String, unit::String, vars::Array; kwargs...)

    var_table = get_res(res, utype, unit)
    var_names = propertynames(var_table.columns)
    time = select(var_table, :time)

    p = plot(title=join([utype, "_", unit]))
    for var in vars
        if var == :time || Symbol(var) ∉ var_names
            continue
        end
        val = select(var_table, Symbol(var))
        plot!(time, val, label=Symbol(var); kwargs...)
    end
    display(p)
end

function plot_res(res::Dict, utype::String, unit::String; kwargs...)

    var_table = get_res(res, utype, unit)
    var_names = propertynames(var_table.columns)
    time = select(var_table, :time)

    p = plot(title=join([utype, "_", unit]))
    for var in var_names
        if var == :time
            continue
        end
        val = select(var_table, var)
        plot!(time, val, label=var; kwargs...)
    end
    display(p)
end

function plot_res_by_scenario(res::Dict, scenario_map::Dict, utype::String, unit::String, var::String; kwargs...)

    time, var_table = get_res(res, scenario_map, utype, unit, var)
    scenarios = sort([parse(Int,i) for i in keys(scenario_map)])
    p = plot(title=join([utype, "_", unit]))
    for s in scenarios
        plot!(time, var_table[s+1,:], label=join(["Scen ", s, ": ", var]); kwargs...)
    end
    display(p)
end

@userplot StackedArea

# source: https://discourse.julialang.org/t/how-to-plot-a-simple-stacked-area-chart/21351/2
# a simple "recipe" for Plots.jl to get stacked area plots
# usage: stackedarea(xvector, datamatrix, plotsoptions)
@recipe function f(pc::StackedArea)
    x, y = pc.args
    n = length(x)
    y = cumsum(y, dims=2)
    seriestype := :shape

    # create a filled polygon for each item
    for c=1:size(y,2)
        sx = vcat(x, reverse(x))
        sy = vcat(y[:,c], c==1 ? zeros(n) : reverse(y[:,c-1]))
        @series (sx, sy)
    end
end

function plot_energy_balance_scenarios(mn_data::Dict, result::Dict, scen_times::Dict, bus::Int; legend_pos="below")
    contribution_dict = get_energy_contribution_at_bus(mn_data["nw"]["1"], bus)
    pos_plots = []
    neg_plots = []
    plot_data = OrderedDict()
    color_palette = palette(:tab10)
    cmap = Dict()
    for (scenario, t_map) in scen_times
        pos_label = []
        neg_label = []
        pos = []
        neg = []
        time = []
        for (utype, unit_dict) in contribution_dict
            for (unit, var_dict) in unit_dict
                for (var, contr) in var_dict
                    if var == "pd"
                        res = get_scenario_data(mn_data, scen_times, scenario, utype, unit, [var])
                    else
                        res = get_scenario_res(result, scen_times, scenario, utype, unit, [var])
                    end
                    if length(colnames(res)) < 3
                        continue
                    end
                    var_id = join([utype, unit, "-", var], " ")
                    var_res = select(res, 3)*contr
                    var_neg = [abs(min(0,i)) for i in var_res]
                    var_pos = [max(0,i) for i in var_res]
                    if isempty(time)
                        time = select(res, 1)
                    end
                    if sum(var_pos) > 0.1
                        if isempty(pos)
                            pos = var_pos
                            pos_label = [var_id]
                        else
                            pos = hcat(pos, var_pos)
                            pos_label = hcat(pos_label, var_id)
                        end
                    end
                    if sum(var_neg) > 0.1
                        if isempty(neg)
                            neg = var_neg
                            neg_label = [var_id]
                        else
                            neg = hcat(neg, var_neg)
                            neg_label = hcat(neg_label, var_id)
                        end       
                    end 
                    if var_id ∉ keys(cmap) && (sum(var_pos) > 0.1 || sum(var_neg) > 0.1)
                        cmap[var_id] = color_palette[length(cmap)+1]
                    end
                end
            end
        end
        
        plot_data[join(["scenario", scenario], " ")] = Dict("time" => time,
                                                       "pos" => pos,
                                                       "neg" => neg*-1,
                                                       "neg_label" => neg_label,
                                                       "pos_label" => pos_label,
                                                       "xlabel" => "Time (h)",
                                                       "ylabel" => "Power injection (MWh)")
    end
    for (k,v) in plot_data
        pos_colors = [cmap[i] for i in v["pos_label"]]
        areaplot = stackedarea(v["time"], v["pos"], color = pos_colors, title = k, legend=false)
        neg_colors = [cmap[i] for i in v["neg_label"]]
        stackedarea!(v["time"], v["neg"], color = neg_colors, size=(700, 230))
        xlabel!("Time (h)")
        ylabel!("Energy (MWh)")
        plot_data[k]["plot"] = areaplot
    end
    sort!(plot_data)
    plots = [v["plot"] for (k,v) in plot_data]
    nplots = length(plot_data)
    plot_rows = Int(max(ceil(nplots/2),1))
    plot_layout = (plot_rows, 2)
    dummy = zeros(1,length(cmap))
    if Bool(nplots%2)
        p2 = stackedarea([0], dummy, label = permutedims([i for i in keys(cmap)]),
        color = permutedims([i for i in values(cmap)]), size=(150, 230),
        showaxis=false, grid=false, legend=(0.2,.7), legendfontsize=10)
        plots = vcat(plots, p2)
    end
    if nplots == 1
        p1 = plot(plots[1], plots[2], layout = @layout([A{0.95h} B{0.3w}]), size=(800, 230*plot_rows))
    else
        p1 = plot(plots..., color = cmap, layout = plot_layout)
    end
    
    if Bool(nplots%2)
        plots = plot(p1, size=(800, 230*plot_rows))
    elseif legend_pos == "below"
        p2 = stackedarea([0], dummy, label = permutedims([i for i in keys(cmap)]),
        color = permutedims([i for i in values(cmap)]),
        showaxis=false, grid=false, legend=(0.4,.95), legendfontsize=10)
        plots = plot(p1,p2, layout = @layout([A; B{0.2h}]), size=(800, 230*plot_rows))
    elseif legend_pos == "right"
        p2 = stackedarea([0], dummy, label = permutedims([i for i in keys(cmap)]),
        color = permutedims([i for i in values(cmap)]),
        showaxis=false, grid=false, legend=(0.15,.5), legendfontsize=10)
        plots = plot(p1,p2, layout = @layout([A{0.95h} B{0.2w}]), size=(800, 230*plot_rows))
    end
    #plots = plot(p1, p2, layout = @layout([A; B]), size=(400*nplots, 300))
    display(plots)
    return plots
end

function plot_inv_matrix(result, scen_times, scenario)
    rectangle(w, h, x, y) = Shape(x .+ [0,w,w,0], y .+ [0,0,h,h])
    iplt = plot()
    scen_inv = get_scenario_inv(result, scen_times)
    inv_res = scen_inv[scenario]
    index = select(inv_res, :unit)
    xlabel = []
    xlabel_pos = []
    ylabel = index
    ylabel_pos = 0.5 .+ index
    for (x, col) in enumerate(colnames(inv_res))
        if col != :unit
            append!(xlabel_pos, x - 0.5)
            append!(xlabel, [string(col)])
            vals = select(inv_res, col)
            for (i,v) in zip(index, vals)
                if v == 1
                    plot!(rectangle(1,1,x-1,i), opacity=.5, color = "green", label = "")
                elseif v == 0
                    plot!(rectangle(1,1,x-1,i), opacity=.5, color = "red", label = "")
                end
            end
        end
    end

    plot!(title="is built?",yticks=(ylabel_pos, ylabel), xticks=(xlabel_pos, xlabel), legend = true)
    ylabel!("unit number")
    plot!(rectangle(0,0,1,1), opacity=.5, label = "True", color = "green")
    plot!(rectangle(0,0,1,1), opacity=.5, label = "False", color = "red")
    display(iplt)
end
# Get variables per unit by times
#load5 = _FP.get_res(result, "load", "5")
#branchdc_1 = _FP.get_res(result, "branchdc", "1")
#branchdc_2 = _FP.get_res(result, "branchdc", "2")
#branchdc_ne_3 = _FP.get_res(result, "branchdc_ne", "3")

#t_vec = Array(1:dim)
# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
#stack_series = [select(branchdc_2, :pt) select(branchdc_ne_3, :pf) select(branchdc_1, :pt) select(load5, :pnce) select(load5, :pcurt) select(load5, :pinter)]
#replace!(stack_series, NaN=>0)
#stack_labels = ["dc branch 2" "new dc branch 3" "dc branch 1"  "reduced load" "curtailed load" "energy not served"]
#stacked_plot = _FP.stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false)