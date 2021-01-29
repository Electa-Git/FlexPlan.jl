# Test script to read in MC years provided by scenario generation and reduction
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP,
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
import Ipopt
import SCS
import Juniper
import JuMP
import Gurobi
import Cbc
import JSON
import CSV
import Plots

function process_results(n_clusters, ts_length, method, number_of_hours, version, file)
    objective = zeros(1,n_clusters)
    calculation_time = zeros(1,n_clusters)
    loadshedding_total = zeros(5,n_clusters)
    loadshedding = zeros(5,number_of_hours)
    loadshifting_up = zeros(5,number_of_hours)
    loadshifting_down = zeros(5,number_of_hours)
    loadshifting_up_total = zeros(5,n_clusters)
    loadshifting_down_total = zeros(5,n_clusters)
    total_wind = zeros(1,n_clusters)
    total_pv = zeros(1,n_clusters)
    total_demand = zeros(1,n_clusters)
    for series_number in 0:(n_clusters - 1)
        print(series_number,"\n")
        monte_carlo_generation = true
        scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}(), "mc" => monte_carlo_generation)
        scenario["sc_years"]["1"] = Dict{String, Any}()
        scenario["sc_years"]["1"]["start"] = 0   # 01.01.2019:00:00 in epoch time  
        scenario["sc_years"]["1"]["probability"] = 1   # 01.01.2019:00:00 in epoch time
        scenario["planning_horizon"] = 10 # in years, to scale generation cost  
        scenario["sc_years"]["1"]["series_number"] = series_number    # 2018 or 2019 for re_ninja data
        scenario["sc_years"]["1"]["length"] = ts_length #"monthly" 
        scenario["sc_years"]["1"]["n_clusters"] = n_clusters #6
        scenario["sc_years"]["1"]["method"] = method #"_pca"
        data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
        data, loadprofile, genprofile = _FP.create_profile_data_italy(data, scenario) # create laod and generation profiles
        _PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
        _FP.add_storage_data!(data) # Add addtional storage data model
        _FP.add_flexible_demand_data!(data) # Add flexible data model
        _FP.scale_cost_data!(data, scenario) # Scale cost data

        dim = number_of_hours * length(data["scenario"])
        extradata = _FP.create_profile_data(dim, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
        # Create data dictionary where time series data is included at the right place
        mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type","scenario","name", "source_version", "per_unit"]))


        ts_length = scenario["sc_years"]["1"]["length"]
        n_clusters = scenario["sc_years"]["1"]["n_clusters"]
        method = scenario["sc_years"]["1"]["method"]
        # Open result file
        result = Dict()
        open(join([join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/","$series_number","_",version,".json"])])) do f
            dicttxt = read(f, String)  # file information to string
            result = JSON.parse(dicttxt)  # parse and transform data
        end
        # Print geo plot of solution and save
        plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
        plot_filename = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/","$series_number","_",version,".kml"])
        _FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)

        #Write objective function value in an array
        objective[series_number+1] = result["objective"] 
        calculation_time[series_number+1] = result["solve_time"] 
        solution = result["solution"]
        for (hour, nw) in solution["nw"]
            for (l, load) in nw["load"]
                loadshedding[parse(Int, l), parse(Int, hour)] = load["pcurt"]*100
                loadshifting_up[parse(Int, l), parse(Int, hour)] = load["pshift_up"]*100
                loadshifting_down[parse(Int, l), parse(Int, hour)] = load["pshift_down"]*100
            end
        end
        total_wind[1,series_number+1] = sum(genprofile[3,:]*data["gen"]["3"]["pmax"])*100 + sum(genprofile[5,:]*data["gen"]["5"]["pmax"])*100
        total_pv[1,series_number+1] = sum(genprofile[6,:]*data["gen"]["6"]["pmax"])*100
        for (l, load) in data["load"]
            l_idx  = parse(Int64, l)
            total_demand[1,series_number+1] = total_demand[1,series_number+1] + sum(loadprofile[l_idx,:])*load["pd"]*100
            p_flex = _FP.plot_flex_demand(result,l_idx,data,extradata)
            plot_name = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/flex_demand","_cl_","$series_number","_load_","$l_idx","_",version,".pdf"])
            Plots.savefig(p_flex,plot_name)
        end
        loadshedding_total[:,series_number+1] = sum(loadshedding, dims=2)
        loadshifting_up_total[:,series_number+1] = sum(loadshifting_up, dims=2)
        loadshifting_down_total[:,series_number+1] = sum(loadshifting_down, dims=2)
    end
    return objective, calculation_time, loadshedding, loadshedding_total, total_wind, total_pv, total_demand, loadshifting_up_total, loadshifting_down_total
end


file = "./test/data/case6_realistic_costs_v1.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage
n_clusters = 6
ts_length = "monthly"
method = "_pca"
version = "v4"
number_of_hours = 720

objective, calculation_time, loadshedding, loadshedding_total, total_wind, total_pv, total_demand, loadshifting_up_total, loadshifting_down_total= process_results(n_clusters, ts_length, method, number_of_hours, version)


p = Plots.plot(1:n_clusters, loadshedding_total[1,:], label= "load 1", xlabel="cluster number",ylabel="Load shedding in MW/year")
Plots.plot!(p, 1:n_clusters, loadshedding_total[2,:], label= "load 2")
Plots.plot!(p, 1:n_clusters, loadshedding_total[3,:], label= "load 3")
Plots.plot!(p, 1:n_clusters, loadshedding_total[4,:], label= "load 4")
Plots.plot!(p, 1:n_clusters, loadshedding_total[5,:], label= "load 5")
ls_plot = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/loadshedding_",version,".pdf"])
Plots.savefig(p,ls_plot)

p = Plots.plot(1:n_clusters, objective'/1e9, label = "Total system cost", xlabel="cluster number", ylabel="Total cost in GEuro")
cost_plot = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/totalcost_",version,".pdf"])
Plots.savefig(p,cost_plot)

p = Plots.plot(1:n_clusters, calculation_time', xlabel="cluster number", ylabel="Calculation time in seconds")
calc_time_plot = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/calculation_time_",version,".pdf"])
Plots.savefig(p,calc_time_plot)



p = Plots.plot(1:n_clusters, total_wind'/1e3, label = "Total wind generation", xlabel="cluster number", ylabel="Total generation and demand in GWh")
Plots.plot!(p, 1:n_clusters, total_pv'/1e3, label = "Total PV generation")
Plots.plot!(p, 1:n_clusters, total_demand'/1e3, label = "Total demand")
wind_plot = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/total_wind_pv_demand_",version,".pdf"])
Plots.savefig(p,wind_plot)

p = Plots.plot(1:n_clusters, sum(loadshedding_total, dims=1)', label= "Total demand curtailment", xlabel="cluster number",ylabel="Load shedding in MW/year")
Plots.plot!(p, 1:n_clusters, sum(loadshifting_up_total, dims=1)', label= "Total upwards demand shifting")
Plots.plot!(p, 1:n_clusters, sum(loadshifting_down_total, dims=1)', label= "Total downwards demand shifting")
load_plot = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/","$n_clusters","_",ts_length,"_clusters",method,"/flex_demand_",version,".pdf"])
Plots.savefig(p,load_plot)