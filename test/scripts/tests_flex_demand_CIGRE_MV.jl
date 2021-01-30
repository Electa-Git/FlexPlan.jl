#%%
# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels
import IndexedTables; const _IT = IndexedTables
using Plots

# Add solver packages,, NOTE: packages are needed handle communication bwteeen solver and Julia/JuMP, 
# they don't include the solver itself (the commercial ones). For instance ipopt, Cbc, juniper and so on should work
#import Ipopt
#import SCS
#import Juniper
#import Mosek
#import MosekTools
import JuMP
#import Gurobi
import Cbc
#import CPLEX

# Solver configurations
#scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
#ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
#cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, seconds = 20, print_level=0)
#gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
#mosek = JuMP.with_optimizer(Mosek.Optimizer)
#juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


# TEST SCRIPT to run multi-period optimisation of demand flexibility for the CIGRE MV benchmark network

# Input parameters:
number_of_hours = 72          # Number of time steps
start_hour = 1                # First time step
n_loads = 13                  # Number of load points
I_load_mon = 2:10                # The load point on which we monitor the load demand
I_bus_mon = 1:11              # The buses for which voltage magnitude is to be monitored
I_load_other = []            # Load point for other loads on the same radial affecting congestion
i_branch_mon = 1              # Index of branch on which to monitor congestion
do_force_congest = false      # True if forcing congestion by modifying branch flow rating of i_branch_congest
rate_congest = 16            # Rating of branch on which to force congestion
load_scaling_factor = 0.85       # Factor with which original base case load demand data should be scaled
use_DC = false                      # True for using DC power flow model; false for using linearized power real-reactive flow model for radial networks

# Vector of hours (time steps) included in case
t_vec = start_hour:start_hour+(number_of_hours-1)

# Input case, in matpower m-file format: Here CIGRE MV benchmark network
file = "./test/data/CIGRE_MV_benchmark_network_flex.m" 

# Filename with extra_load array with demand flexibility model parameters
filename_load_extra = "./test/data/CIGRE_MV_benchmark_network_flex_load_extra.csv"

# Data manipulation (per unit conversions and matching data models)
data = _PM.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)

# Handle possible missing auxiliary fields of the MATPOWER case file
field_names = ["busdc","busdc_ne","branchdc","branchdc_ne","convdc","convdc_ne","ne_storage","storage","storage_extra"]
for field_name in field_names
      if !haskey(data,field_name)
            data[field_name] = Dict{String,Any}()
      end
end

# Read load demand series and assign (relative) profiles to load points in the network
data,loadprofile,genprofile = _FP.create_profile_data_norway(data, number_of_hours)

# Add extra_load array for demand flexibility model parameters
data = _FP.read_case_data_from_csv(data,filename_load_extra,"load_extra")

# Scale load at all of the load points
for i_load = 1:n_loads
      data["load"][string(i_load)]["pd"] = data["load"][string(i_load)]["pd"] * load_scaling_factor
      data["load"][string(i_load)]["qd"] = data["load"][string(i_load)]["qd"] * load_scaling_factor
end

# Modify branch ratings to artificially cause congestions
if do_force_congest
      data["branch"][string(i_branch_mon)]["rate_a"] = rate_congest
      data["branch"][string(i_branch_mon)]["rate_b"] = rate_congest
      data["branch"][string(i_branch_mon)]["rate_c"] = rate_congest
end

if use_DC
      _PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
end
_FP.add_flexible_demand_data!(data) # Add flexible data model

extradata = _FP.create_profile_data(number_of_hours, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
if use_DC
      mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))
else
      mn_data = _FP.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))
end

# Add PowerModels(ACDC) settings
if use_DC
      if length(data["ne_branch"]) > 0
            do_replace_branch =  ( data["ne_branch"]["1"]["replace"] == 1 )
      else
            do_replace_branch = false  
      end
      s = Dict("output" => Dict("branch_flows" => true), "allow_line_replacement" => do_replace_branch, "conv_losses_mp" => false, "process_data_internally" => false)
else
      s = Dict("output" => Dict("branch_flows" => true))
end

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
if use_DC
      result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)
else
      result_test1 = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc, multinetwork=true; setting = s)
end

# Printing to screen the branch investment decisions in the solution 
for i_ne_branch = 1:length(result_test1["solution"]["nw"]["1"]["ne_branch"])
      println("Is candidate branch ", i_ne_branch, " built: ", result_test1["solution"]["nw"]["1"]["ne_branch"][string(i_ne_branch)]["built"])
end

# Plot branch flow on congested branch
if !isnan(i_branch_mon)
      p_congest = _FP.plot_branch_flow(result_test1,i_branch_mon,data,"branch")
      savefig(p_congest,"branch_flow_congest")
end

# Extract results for branch to monitor
branch_mon = _FP.get_vars(result_test1, "branch", string(i_branch_mon))

# Extract results for new branch (assuming there only being one, and that it has a relevant placement)
branch_new = _FP.get_vars(result_test1, "ne_branch","1")

# Extract results for load points to monitor 
# (this code got quite ugly but I do not want to re-write/extend the get_vars functions right now...)
pflex_load_mon = zeros(number_of_hours,1)
pnce_load_mon = zeros(number_of_hours,1)
pcurt_load_mon = zeros(number_of_hours,1)
pd_load_mon = zeros(number_of_hours,1)
ence_load_mon = zeros(number_of_hours,1)
pshift_up_load_mon = zeros(number_of_hours,1)
pshift_down_load_mon = zeros(number_of_hours,1)
for i_load_mon in I_load_mon
      load_mon = _FP.get_vars(result_test1, "load", string(i_load_mon))
      global pflex_load_mon += _IT.select(load_mon, :pflex)
      global pnce_load_mon += _IT.select(load_mon, :pnce)
      global pcurt_load_mon += _IT.select(load_mon, :pcurt)
      global ence_load_mon += _IT.select(load_mon, :ence)
      global pshift_up_load_mon += _IT.select(load_mon, :pshift_up)
      global pshift_down_load_mon += _IT.select(load_mon, :pshift_down)
      global pd_load_mon += transpose(extradata["load"][string(i_load_mon)]["pd"])
end

# Extract results for other loads on the radial beyond the node that is monitored
pflex_load_other = zeros(number_of_hours,1)
pd_load_other = zeros(number_of_hours,1)
for i_load_other in I_load_other
      load_other = _FP.get_vars(result_test1, "load", string(i_load_other))
      global pflex_load_other += _IT.select(load_other, :pflex)
      global pd_load_other += transpose(extradata["load"][string(i_load_other)]["pd"])
end

# Plot bus voltage magnitudes
i_bus = I_bus_mon[1]
voltage_plot = _FP.plot_var(result_test1,"bus",string(i_bus),"vm",label = string("bus ", i_bus), xlabel = "time (h)", ylabel = "voltage magnitude (p.u.)")
for i_bus in I_bus_mon[2:end]
      _FP.plot_var!(result_test1,"bus",string(i_bus),"vm")
      voltage_plot.series_list[end].plotattributes[:label] = string("bus ", i_bus)
end
savefig(voltage_plot, "voltage.png")

# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
branch_congest_flow = _IT.select(branch_mon, :pt)*-1
if use_DC
      branch_new_flow = _IT.select(branch_new, :p_ne_to)*-1
else
      branch_new_flow = _IT.select(branch_new, :pt)*-1
end
bus_mod_balance = branch_congest_flow - pflex_load_other
stack_series = [bus_mod_balance branch_new_flow pnce_load_mon pcurt_load_mon]
stack_labels = ["branch flow old branch" "branch flow new branch" "reduced load at buses" "curtailed load at buses"]
stacked_plot = _FP.stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false, ylabel = "load (MW)")
load_input = pd_load_mon + pd_load_other
plot!(t_vec, load_input, color=:red, width=3.0, label="base demand", line=:dash)
load_flex = pflex_load_mon + pflex_load_other
plot!(t_vec, load_flex, color=:blue, width=3.0, label="flexible demand", line=:dash)
savefig(stacked_plot, "load_mod_balance.png")

# Plot energy not served
plot_not_served = plot(t_vec, ence_load_mon, color=:black, width=3.0,
                           label="total energy not served", xlabel="time (h)",
                           ylabel="energy (MWh)", legend=false, gridalpha=0.5)

# Make legend in energy not served plot
pos = (0,.7)
v1legend = _FP.stackedarea([0], [[0] [0] [0] [0]], label=stack_labels)
plot!([0], label = "base demand", color=:red, line=:dash, width=3.0)
plot!([0], label = "flexible demand", color=:blue, line=:dash, width=3.0)
plot!([0], label = "total energy not served", color=:black, width=3.0, showaxis=false, grid=false,
      legend=pos, foreground_color_legend = nothing)

# Add the two plots (energy balance and shifted demand) vertially
#   and the legend on the side (with a given width -> .2w)
vertical_plot = plot(stacked_plot, plot_not_served, v1legend, layout = @layout([[A; B] C{.22w}]),
                     size=(700, 400))
savefig(vertical_plot, "load_mod_balance_vertical.png")


# Plot the shifted demand
stack_series = pshift_up_load_mon
label = "pshift_up"
plot_energy_shift = _FP.stackedarea(t_vec, stack_series,  labels=label, alpha=0.7, color=:blue, legend=false)
stack_series = pshift_down_load_mon*-1
label = "pshift_down"
_FP.stackedarea!(t_vec, stack_series, labels=label, xlabel="time (h)", ylabel="load shifted (MW)",
             alpha=0.7, color=:red, legend=false, gridalpha=0.5)

# Make legend in shifted demand plot
pos = (0,.7)
v2legend = _FP.stackedarea([0], [[0] [0] [0] [0]], label=stack_labels)
plot!([0], label = "base demand", color=:red, line=:dash, width=3.0)
plot!([0], label = "flexible demand", color=:blue, line=:dash, width=3.0)
_FP.stackedarea!([0],[0],label="load shift up", color=:blue)
_FP.stackedarea!([0],[0], showaxis=false, grid=false, label="load shift down", legend=pos, color=:red,
             foreground_color_legend = nothing)
# Add the two plots (energy balance and shifted demand) vertially
#   and the legend on the side (with a given width -> .2w)
vshift_plot = plot(stacked_plot, plot_energy_shift, v2legend, layout = @layout([[A; B] C{.2w}]),
                   size=(700, 400))
savefig(vshift_plot, "load_mod_balance_vshift.png")
