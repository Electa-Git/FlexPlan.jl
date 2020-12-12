#%%
# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels
import CSV
import IndexedTables

include("../../src/io/plots.jl")
include("../../src/io/get_result.jl")
include("../../src/io/get_data.jl")
include("../../src/io/read_case_data_from_csv.jl")

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
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
#gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
#mosek = JuMP.with_optimizer(Mosek.Optimizer)
#juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)


# TEST SCRIPT to run multi-period optimisation of demand flexibility for the CIGRE MV benchmark network

# Input parameters:
number_of_hours = 96          # Number of time steps
start_hour = 1                # First time step
n_loads = 13                  # Number of load points
i_load_mon = 4                # The load point on which we monitor the load demand
I_load_other = 5              # Load point for other loads on the same radial affecting congestion
i_branch_mon = 4              # Index of branch on which to monitor congestion
do_force_congest = true      # True if forcing congestion by modifying branch flow rating of i_branch_congest
do_mod_single_load = true     # False if modifying all loads by load scaling factor; true if modifying only load #i_load_mon
rate_congest = 0.8            # Rating of branch on which to force congestion
load_scaling_factor = 1       # Factor with which original base case load demand data should be scaled


# Vector of hours (time steps) included in case
t_vec = start_hour:start_hour+(number_of_hours-1)

file = "./test/data/CIGRE_MV_benchmark_network_flex.m" # Input case, in matpower m-file format: Here CIGRE MV benchmark network

# Filename with extra_load array with demand flexibility model parameters
filename_load_extra = "./test/data/CIGRE_MV_benchmark_network_flex_load_extra.csv"

#Pkg.add("CSV")
fname_Norway = "./test/data/demand_Norway_2015.csv"
demand_data = CSV.read(fname_Norway)
demand = demand_data[:,2:end]
n_hours_data = size(demand,1)
n_loads_data = size(demand,2)
demand_pu = zeros(n_hours_data,n_loads_data)
for i_load_data = 1:n_loads_data
      demand_pu[:,i_load_data] = demand[:,i_load_data] ./ maximum(demand[:,i_load_data])
end
loadprofile = demand_pu[1:number_of_hours,1:n_loads]'
#loadprofile = [zeros(1,number_of_hours); demand_pu[1:number_of_hours,:]'; zeros(3,number_of_hours)]

# Data manipulation (per unit conversions and matching data models)
data = _PM.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)

# Add extra_load array for demand flexibility model parameters
data = read_case_data_from_csv(data,filename_load_extra,"load_extra")

if !do_mod_single_load
      # Scale load at one of the load points
      data["load"][string(i_load_mon)]["pd"] = data["load"][string(i_load_mon)]["pd"] * load_scaling_factor
      data["load"][string(i_load_mon)]["qd"] = data["load"][string(i_load_mon)]["qd"] * load_scaling_factor
else
      # Scale load at all of the load points
      for i_load = 1:n_loads
            data["load"][string(i_load)]["pd"] = data["load"][string(i_load)]["pd"] * load_scaling_factor
            data["load"][string(i_load)]["qd"] = data["load"][string(i_load)]["qd"] * load_scaling_factor
      end
end

# Modify branch ratings to artificially cause congestions
if do_force_congest
      data["branch"][string(i_branch_mon)]["rate_a"] = rate_congest
      data["branch"][string(i_branch_mon)]["rate_b"] = rate_congest
      data["branch"][string(i_branch_mon)]["rate_c"] = rate_congest
end

_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_flexible_demand_data!(data) # Add flexible data model

extradata = _FP.create_profile_data(number_of_hours, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)




# Plot branch flow on congested branch
if !isnan(i_branch_mon)
      p_congest = plot_branch_flow(result_test1,i_branch_mon,data,"branch")
      savefig(p_congest,"branch_flow_congest")
end

# Extract results for branch and load point to monitor
load_mon = get_vars(result_test1, "load", string(i_load_mon))
branch_mon = get_vars(result_test1, "branch", string(i_branch_mon))

# Extract results for other loads on the radial beyond the node that is monitored
pflex_load_other = zeros(number_of_hours,1)
pd_load_other = zeros(number_of_hours,1)
for i_load_other in I_load_other
      load_other = get_vars(result_test1, "load", string(i_load_other))
      pflex_load_other = pflex_load_other + select(load_other, :pflex)
      pd_load_other = pd_load_other + transpose(extradata["load"][string(i_load_other)]["pd"])
end


# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
branch_congest_flow = select(branch_mon, :pt)*-1
bus_mod_balance = branch_congest_flow - select(load_other, :pflex)
stack_series = [pflex_load_other bus_mod_balance select(load_mon, :pnce) select(load_mon, :pcurt)]
stack_labels = ["branch flow to rest of the radial" "net branch flow to load bus" "reduced load" "curtailed load" " " " "]
stacked_plot = stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false)
load_input = transpose(extradata["load"][string(i_load_mon)]["pd"]) + pd_load_other
plot!(t_vec, load_input, color=:red, width=3.0, label="base demand", line=:dash)
load_flex = select(load_mon, :pflex) + pflex_load_other
plot!(t_vec, load_flex, color=:blue, width=3.0, label="flexible demand", line=:dash)
#plot_var!(result_test1, "load", string(i_load_mon),"pflex", label="flexible demand",
#          ylabel="power (p.u.)", color=:blue, width=3.0, line=:dash, gridalpha=0.5)
savefig(stacked_plot, "load_mod_balance.png")

# Plot energy not served
plot_not_served = plot_var(result_test1, "load", string(i_load_mon), "ence", color=:black, width=3.0,
                           label="total energy not served", xlabel="time (h)",
                           ylabel="energy (p.u.)", legend=false, gridalpha=0.5)

# Make legend in energy not served plot
pos = (0,.7)
v1legend = stackedarea([0], [[0] [0] [0] [0] [0]], label=stack_labels)
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
stack_series = select(load_mon, :pshift_up)
label = "pshift_up"
plot_energy_shift = stackedarea(t_vec, stack_series,  labels=label, alpha=0.7, color=:blue, legend=false)
stack_series = select(load_mon, :pshift_down)*-1
label = "pshift_down"
stackedarea!(t_vec, stack_series, labels=label, xlabel="time (h)", ylabel="load shifted (p.u.)",
             alpha=0.7, color=:red, legend=false, gridalpha=0.5)

# Make legend in shifted demand plot
pos = (0,.7)
v2legend = stackedarea([0], [[0] [0] [0] [0] [0]], label=stack_labels)
plot!([0], label = "base demand", color=:red, line=:dash, width=3.0)
plot!([0], label = "flexible demand", color=:blue, line=:dash, width=3.0)
stackedarea!([0],[0],label="load shift up", color=:blue)
stackedarea!([0],[0], showaxis=false, grid=false, label="load shift down", legend=pos, color=:red,
             foreground_color_legend = nothing)
# Add the two plots (energy balance and shifted demand) vertially
#   and the legend on the side (with a given width -> .2w)
vshift_plot = plot(stacked_plot, plot_energy_shift, v2legend, layout = @layout([[A; B] C{.2w}]),
                   size=(700, 400))
savefig(vshift_plot, "load_mod_balance_vshift.png")
