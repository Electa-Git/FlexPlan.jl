# Test script to read in MC years provided by scenario generation and reduction
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

include("../io/create_profile.jl")

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

# Solver configurations
scs = _FP.optimizer_with_attributes(SCS.Optimizer, "max_iters"=>100000)
ipopt = _FP.optimizer_with_attributes(Ipopt.Optimizer, "tol"=>1e-4, "print_level"=>0)
cbc = _FP.optimizer_with_attributes(Cbc.Optimizer, "tol"=>1e-4, "print_level"=>0)
gurobi = Gurobi.Optimizer
juniper = _FP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver"=>ipopt, "mip_solver"=>cbc, "time_limit"=>7200)

cd("/Users/hergun/.julia/dev/FlexPlan")
for year = 0:1
    number_of_hours = 10 # Number of time points
    monte_carlo_generation = true
    file = "./test/data/case6_realistic_costs.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage
    scenario = Dict{String, Any}("hours" => number_of_hours, "sc_years" => Dict{String, Any}(), "mc" => monte_carlo_generation)
    scenario["sc_years"]["1"] = Dict{String, Any}()
    scenario["sc_years"]["1"]["year"] = year    # 2018 or 2019 for re_ninja data
    scenario["sc_years"]["1"]["start"] = 0   # 01.01.2019:00:00 in epoch time
    scenario["sc_years"]["1"]["probability"] = 1   # 01.01.2019:00:00 in epoch time
    scenario["planning_horizon"] = 1 # in years, to scale generation cost
    #############################################################

    data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
    data, loadprofile, genprofile = create_profile_data_italy(data, scenario) # create laod and generation profiles
    _PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
    _FP.add_storage_data!(data) # Add addtional storage data model
    _FP.add_flexible_demand_data!(data) # Add flexible data model
    _FP.scale_cost_data!(data, scenario) # Scale cost data

    dim = number_of_hours * length(data["scenario"])
    extradata = create_profile_data(dim, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
    # Create data dictionary where time series data is included at the right place
    mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type","scenario","name", "source_version", "per_unit"]))

    # Plot all candidates pre-optimisation
    plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
    plot_filename = "./test/data/output_files/candidates_italy.kml"
    _FP.plot_geo_data(mn_data, plot_filename, plot_settings)

    # Add PowerModels(ACDC) settings
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false)
    # Build optimisation model, solve it and write solution dictionary:
    # This is the "problem file" which needs to be constructed individually depending on application
    # In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
    result = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, gurobi; setting = s)

    result_file = join(["/Users/hergun/Box Sync/Projects/FlexPlan/WP1/Code/testing/mc_tests/35_years/year_","$year",".json"])
    stringdata_result = JSON.json(result)
    open(result_file, "w") do f
            write(f, stringdata_result)
    end
end