using Plots

"""
    plot_branch_flow(results,i_branch,input_data)

Plot time series for power flow on a branch no. 'i_branch' in the network
in the multi-period OPF solution 'results'. If input data Dict 'input_data'
is provided, the branch flow is compared with the branch power ratings in
the plots. If 'i_branch' is _not_ provided, all branches are plotted.
"""
function plot_branch_flow(results, i_branch_plot=[], input_data=[])

    # Input argument checks
    if haskey(results, "solution")
        if haskey(results["solution"], "nw")
            sol_1 = results["solution"]["nw"]["1"]
        else
            error("Input argument results has to be the result of a multi-period OPF problem")
        end
    end

    # Number of branches in network
    n_branches = length(sol_1["branch"])
    
    # Extract branch power flow rating (rate_a)
    if !isempty(input_data)
        rate_a = zeros(n_branches, 1)
        for i_branch = 1:n_branches
            rate_a[i_branch] = data["branch"][string(i_branch)]["rate_a"]
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
            pt[t,i_branch] = results["solution"]["nw"][string(t)]["branch"][string(i_branch)]["pt"]           
        end
    end

    # Plotting branch power flows
    p = plot(xlabel="Time step", ylabel="Power flow (p.u.)")
    if !isempty(i_branch_plot)
        pt_plot = pt[:,i_branch_plot]
        plot!(p, t_vec, pt_plot, label=string("Flow on branch #", i_branch_plot), color=:red)
        if !isempty(rate_a)
            # Plot branch power rating (if provided)
            rate_a_plot = ones(n_time_steps, 1) * rate_a[i_branch_plot,1]
            plot!(p, t_vec, rate_a_plot, label=string("Rating of branch #", i_branch_plot), color=:black, line=:dash)
            plot!(p, t_vec, -rate_a_plot, label=string("Rating of branch #", i_branch_plot), color=:black, line=:dash)
        end
    else
        # Plot power flow for all branches if branch not specified
        plot!(p, pt)
    end

    return p
end