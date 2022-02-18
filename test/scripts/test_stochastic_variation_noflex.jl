# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

include("../io/create_profile.jl")
include("../io/plots.jl")

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP,
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
import Ipopt
import SCS
import Juniper
import Mosek
import MosekTools
import JuMP
import Gurobi
import Cbc
import JSON
import CSV
import Plots

# Solver configurations
scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)

res = ones(1,11)
idx = 0
for p1 in 0:0.1:1
    global idx = idx + 1
    p2 = 1-p1
    ################# INPUT PARAMETERS ######################
    number_of_hours = 168 # Number of time points
    planning_horizon = 10 # years to scale generation costs
    file = "./test/data/case6_stoch_noflex.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage

    scenario = Dict{String, Any}("hours" => number_of_hours, "planning_horizon" => planning_horizon, "sc_years" => Dict{String, Any}())
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["year"] = 2019
    scenario["sc_years"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
    scenario["sc_years"]["1"]["probability"] = p1
    scenario["sc_years"]["2"] = Dict{String, Any}()
    scenario["sc_years"]["2"]["year"] = 2018
    scenario["sc_years"]["2"]["start"] = 1514764800000   # 01.01.2018:00:00 in epoch time
    scenario["sc_years"]["2"]["probability"] = p2
    #######################cs######################################
    # TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments for the Italian case

    data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
    data, loadprofile, genprofile = create_profile_data_italy(data, scenario) # create laod and generation profiles
    _PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
    _FP.add_storage_data!(data) # Add addtional storage data model
    _FP.add_flexible_demand_data!(data) # Add flexible data model
    _FP.scale_cost_data!(data, scenario) # Scale cost data

    # More renewables in 2019 scenario
    genprofile[1,1:number_of_hours] = genprofile[1,1:number_of_hours] * 0.8
    genprofile[2,1:number_of_hours] = genprofile[2,1:number_of_hours] * 0.8
    genprofile[5,1:number_of_hours] = genprofile[5,1:number_of_hours] * 2
    genprofile[6,1:number_of_hours] = genprofile[6,1:number_of_hours] * 2
    # change generation locations 2018 scenario
    genprofile[1,number_of_hours+1:end] = genprofile[1,number_of_hours+1:end] * 1.5
    genprofile[2,number_of_hours+1:end] = genprofile[2,number_of_hours+1:end] * 1.5
    genprofile[5,number_of_hours+1:end] = genprofile[5,number_of_hours+1:end] * 0.5
    genprofile[6,number_of_hours+1:end] = genprofile[6,number_of_hours+1:end] * 0.5


    dim = number_of_hours * length(data["scenario"])
    extradata = create_profile_data(dim, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
    # Create data dictionary where time series data is included at the right place
    mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "scenario", "scenario_prob", "name", "source_version", "per_unit"]))
    # Plot all candidates pre-optimisation
    plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
    plot_filename = "./test/data/output_files/candidates_italy.kml"
    _FP.plot_geo_data(mn_data, plot_filename, plot_settings)

    # Add PowerModels(ACDC) settings
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false,  "add_co2_cost" => false)
    # Build optimisation model, solve it and write solution dictionary:
    # This is the "problem file" which needs to be constructed individually depending on application
    # In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
    result = _FP.stoch_flex_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)
    # Plot final topology
    plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
    plot_filename = join(["./test/data/output_files/lec","$idx","_noflex.kml"])
    _FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)

    p = plot_profile_data(extradata, number_of_hours, Dict() ,["3" "5" "6"])
    lp_file = join(["./test/data/output_files/profile_","$idx","_noflex.png"])
    Plots.savefig(p,lp_file)


    for ld in 1:5
        p = plot_flex_demand(result, ld, data, extradata)
        lp_result = join(["./test/data/output_files/load_porfile_","$ld","_","$idx","_noflex.png"])
        Plots.savefig(p,lp_result)
    end

    res[1, idx] = result["objective"]

    result_file = join(["./test/data/output_files/stoch_result_","$idx","_noflex.json"])
    stringdata_result = JSON.json(result)
    open(result_file, "w") do f
            write(f, stringdata_result)
    end
end