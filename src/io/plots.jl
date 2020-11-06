using Plots


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
