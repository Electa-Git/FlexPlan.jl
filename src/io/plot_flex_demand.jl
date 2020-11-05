using Plots

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