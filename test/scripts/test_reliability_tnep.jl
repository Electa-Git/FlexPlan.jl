# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

include("../io/create_profile.jl")
include("../io/get_result.jl")
include("../io/plots.jl")

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP,
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
import Ipopt
import SCS
import Juniper
#import Mosek
#import MosekTools
import JuMP
#import Gurobi
import Cbc
import JSON
import CSV

# Solver configurations
scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
#gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
#mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)

################# INPUT PARAMETERS ######################
number_of_hours = 60 # Number of time points
file = "./test/data/case6_reliability.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage

scenario = Dict{String, Any}("hours" => number_of_hours, "contingency" => Dict{String, Any}())
scenario["contingency"]["0"] = Dict{String, Any}()
scenario["contingency"]["0"]["year"] = 2019
scenario["contingency"]["0"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["0"]["probability"] = 0.98
scenario["contingency"]["0"]["faults"] = Dict()
scenario["contingency"]["1"] = Dict{String, Any}()
scenario["contingency"]["1"]["year"] = 2019
scenario["contingency"]["1"]["start"] = 1546300800000   # 01.01.2019:00:00 in epoch time
scenario["contingency"]["1"]["probability"] = 0.01
scenario["contingency"]["1"]["faults"] = Dict("branchdc" => [1])
scenario["contingency"]["2"] = Dict{String, Any}()
scenario["contingency"]["2"]["year"] = 2019
scenario["contingency"]["2"]["start"] = 1546300800000 #1514764800000   # 01.01.2018:00:00 in epoch time
scenario["contingency"]["2"]["probability"] = 0.01
scenario["contingency"]["2"]["faults"] = Dict("branchdc_ne" => [3])
scenario["contingency"]["3"] = Dict{String, Any}()
scenario["contingency"]["3"]["year"] = 2019
scenario["contingency"]["3"]["start"] = 1546300800000 #1514764800000   # 01.01.2018:00:00 in epoch time
scenario["contingency"]["3"]["probability"] = 0.01
scenario["contingency"]["3"]["faults"] = Dict("branchdc" => [2])
scenario["utypes"] = [ "branchdc", "branchdc_ne"] # type of lines considered in contingencies
scenario["planning_horizon"] = 1 # in years, to scale generation cost
#######################cs######################################
# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments for the Italian case

data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)
data, contingency_profile, loadprofile, genprofile = create_contingency_data_italy(data, scenario) # create load and generation profiles
_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
_FP.scale_cost_data!(data, scenario) # Scale cost data

dim = number_of_hours * length(data["contingency"])
extradata = create_contingency_data(dim, data, contingency_profile, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "contingency", "contingency_prob", "name", "source_version", "per_unit"]))

# Plot all candidates pre-optimisation
plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
plot_filename = "./test/data/output_files/candidates_italy.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result = _FP.reliability_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)
# # Plot final topology
# plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
# plot_filename = "./test/data/output_files/results_italy.kml"
# _FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result)

# Espen

res_struct = get_res_structure(result)

utypes = get_utypes(result)
gen_vars = get_utype_vars(result,"gen")
branch_2 = get_res(result, "branch", "1")

plot_res_by_scenario(result, data["contingency"], "gen","1", "pg")

#plot_res_by_scenario(result,"branch","1", 20)


# Get variables per unit by times
load5 = get_res(result, "load", "5")
branchdc_1 = get_res(result, "branchdc", "1")
branchdc_2 = get_res(result, "branchdc", "2")
branchdc_ne_3 = get_res(result, "branchdc_ne", "3")

t_vec = Array(1:dim)
# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
using JuliaDB
using Plots
stack_series = [select(branchdc_2, :pt) select(branchdc_ne_3, :pf) select(branchdc_1, :pt) select(load5, :pred) select(load5, :pcurt) select(load5, :pinter)]
replace!(stack_series, NaN=>0)
stack_labels = ["dc branch 2" "new dc branch 3" "dc branch 1"  "reduced load" "curtailed load" "energy not served"]
stacked_plot = stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false)
#... lines for base and flexible demand
bus_nr = 5
#load5_input = transpose(extradata["load"][string(bus_nr)]["pd"])
#_FP.plot!(t_vec, load5_input, color=:red, width=3.0, label="base demand", line=:dash)
plot_res!(result, "load", string(bus_nr),"pflex", label="flexible demand",
          ylabel="power (p.u.)", color=:blue, width=3.0, line=:dash, gridalpha=0.5)
#... save figure
savefig(stacked_plot, "bus5_balance.png")



# Plot energy not served
plot_not_served = plot_res(result, "load", "5", "ered", color=:black, width=3.0,
                           label="total energy not served", xlabel="time (h)",
                           ylabel="energy (p.u.)", legend=false, gridalpha=0.5)

enbal_plot = plot_energy_balance_scenarios(data, result, "contingency", 5)
savefig(enbal_plot, "bus5_enbal.png")
# Make legend in new plot
#pos = (0,.7)
#v1legend = stackedarea([0], [[0] [0] [0] [0] [0]], label=stack_labels)
#plot!([0], label = "base demand", color=:red, line=:dash, width=3.0)
#plot!([0], label = "flexible demand", color=:blue, line=:dash, width=3.0)
#plot!([0], label = "total energy not served", color=:black, width=3.0, showaxis=false, grid=false,
#      legend=pos, foreground_color_legend = nothing)

# Add the two plots (energy balance and shifted demand) vertially
#   and the legend on the side (with a given width -> .2w)
#vertical_plot = plot(stacked_plot, plot_not_served, v1legend, layout = @layout([[A; B] C{.22w}]),
#                     size=(700, 400))
#savefig(vertical_plot, "bus5_balance_vertical.png")
