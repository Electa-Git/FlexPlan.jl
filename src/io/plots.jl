using Plots


function plot_profile_data(extradata, number_of_hours, solution = Dict(), res_gen_ids = nothing, scenario = "1")
    # Plots load and generation profile data at grid level.
    # See test_italian_case.jl for an example of how to use.
    # scenario: id of the scenario data we want to plot

    hours = collect(1:number_of_hours)

    nw_1 = number_of_hours*(parse(Int,scenario) - 1) + 1
    nw_end = number_of_hours*parse(Int,scenario)
    nw_ids = collect(nw_1:nw_end)

    # compute total load in the system at each hour
    total_load_pu = zeros(number_of_hours)
    for (load_id,load) in extradata["load"]
        hour = 1
        for nw in nw_ids
            total_load_pu[hour] += load["pd"][nw]
            hour += 1
        end
    end
    p = plot(hours,total_load_pu,label="Total load (p.u.)",xlabel="Time (h)",
        ylabel="Load/generation (p.u.)",xlim=(0,number_of_hours))

    # compute total generation capacity of the system at each hour
    tot_gen_cap_pu = zeros(number_of_hours)
    for (gen_id,gen) in extradata["gen"]
        hour = 1
        for nw in nw_ids
            tot_gen_cap_pu[hour] += gen["pmax"][nw]
            hour += 1
        end
    end
    plot!(hours,tot_gen_cap_pu,label="Total generation capacity (p.u.)")

    # compute actual total generation at each hour if solution provided
    if haskey(solution,"nw")
        actual_gen_pu = zeros(number_of_hours)

        hour = 1
        for nw_id in nw_ids
            nw = solution["nw"][string(nw_id)]
            for (gen_id,gen) in nw["gen"]
                actual_gen_pu[hour] += gen["pg"]
            end
            hour += 1
        end
        plot!(hours,actual_gen_pu,label="Actual generation (p.u.)")
    end


    # compute RES and traditional generation capacity at each hour if res_gen_ids != nothing
    if !isnothing(res_gen_ids)
        tot_res_cap_pu = zeros(number_of_hours)
        tot_trad_cap_pu = zeros(number_of_hours)

        for (gen_id,gen) in extradata["gen"]
            hour = 1
            for nw in nw_ids
                if gen_id in res_gen_ids
                    tot_res_cap_pu[hour] += gen["pmax"][nw]
                else
                    tot_trad_cap_pu[hour] += gen["pmax"][nw]
                end
                hour += 1
            end
        end
        plot!(hours,tot_trad_cap_pu,label="Trad. generation capacity (p.u.)")
        plot!(hours,tot_res_cap_pu,label="RES generation capacity (p.u.)")
    end

    return p
end

function plot_storage_data(data, number_of_hours, solution, scenario = "1")
    # Plots storage charge/discharge power and energy level at each
    # time step and for each existing and candidate storage asset.
    # See test_italian_case.jl for an example of how to use.

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

    hours = collect(1:number_of_hours)

    nw_1 = number_of_hours*(parse(Int,scenario) - 1) + 1
    nw_end = number_of_hours*parse(Int,scenario)
    nw_ids = collect(nw_1:nw_end)


    st_power = zeros((n_st+n_st_ne,number_of_hours)) #storage power (charge/discharge) at each time step
    st_energy = zeros((n_st+n_st_ne,number_of_hours)) #stoarge energy level at each time step

    hour = 1
    for nw_id in nw_ids
        nw = nws[string(nw_id)]
        # existing storage assets
        if haskey(nw,"storage")
            for (index,st) in nw["storage"]
                i = parse(Int,index)
                if st["sc"] > 0 # charge taken as positive power
                    st_power[i,hour] = st["sc"]
                    if st["sd"] != 0 println("storage charge and discharge not exclsuive") end
                elseif st["sd"] > 0 # discharge taken as negative power
                    st_power[i,hour] = -st["sd"]
                    if st["sc"] != 0 println("storage charge and discharge not exclsuive") end
                end
                # energy level: divide storage energy by energy rating
                st_energy[i,hour] = st["se"]/data["storage"][index]["energy_rating"]
            end
        end
        # candidate storage assets
        if haskey(nw,"ne_storage")
            for (index_ne,st_ne) in nw["ne_storage"]
                if st_ne["isbuilt"] == 1
                    i = parse(Int,index_ne)
                    if st_ne["sc_ne"] > 0 # charge taken as positive power
                        st_power[i+n_st,hour] = st_ne["sc_ne"]
                    elseif st_ne["sd_ne"] > 0 # discharge taken as negative power
                        st_power[i+n_st,hour] = -st_ne["sd_ne"]
                    end
                    # energy level: divide storage energy by energy rating
                    st_energy[i+n_st,hour] = st_ne["se_ne"]/data["ne_storage"][index_ne]["energy_rating"]
                end
            end
        end
        hour += 1
    end

    # remove rows of not built storage assets
    index = [1:n_st;]
    if haskey(nws["1"],"ne_storage")
        for (ne_st_ind,ne_st) in nws["1"]["ne_storage"]
            if ne_st["isbuilt"] == 1
                push!(index,n_st + parse(Int,ne_st_ind))
            end
        end
    end
    st_power = st_power[index,:]
    st_energy = st_energy[index,:]

    # labels for plottingg
    labels1 = ["Storage $i" for i in 1:n_st]
    if haskey(nws["1"],"ne_storage")
        labels2 = ["Candidate storage $(ne_st_ind)" for (ne_st_ind,ne_st) in nws["1"]["ne_storage"] if ne_st["isbuilt"] == 1]
    else
        labels2 = []
    end
    labels = append!(labels1,labels2)
    labels = reshape(labels, 1, :)

    p1 = bar(hours,st_power',bar_position = :dodge,label=labels,xlabel="Time (h)",
            ylabel="Storage charge/dicharge (p.u.)",xlim=(0,number_of_hours))
    p2 = bar(hours,st_energy',bar_position = :dodge,xlabel="Time (h)",label=labels,
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


function plot_var(res::Dict, utype::String, unit::String, var::String; kwargs...)

    var_table = get_vars(res, utype, unit)

    time = select(var_table, :time)
    val = select(var_table, Symbol(var))

    plot(time, val; kwargs...)
end

function plot_var!(res::Dict, utype::String, unit::String, var::String; kwargs...)

    var_table = get_vars(res, utype, unit)

    time = select(var_table, :time)
    val = select(var_table, Symbol(var))

    plot!(time, val, label=var; kwargs...)
end

function plot_var(res::Dict, utype::String, unit::String, vars::Array; kwargs...)

    var_table = get_vars(res, utype, unit)
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

function plot_var(res::Dict, utype::String, unit::String; kwargs...)

    var_table = get_vars(res, utype, unit)
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
