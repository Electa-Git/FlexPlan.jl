#%%
# Import relevant packages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels

include("../io/plots.jl")
include("../io/create_profile.jl")
include("../io/get_result.jl")
include("../io/get_data.jl")

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


# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments

# Input parameters:
number_of_hours = 96               # Number of time steps
start_hour = 1                     # First time step
n_loads = 5                        # Number of load points
i_load_mod = 5                     # The load point on which we modify the demand profile
out_dir = "test/data/output_files" # Output directory

file = "./test/data/case6_flex.m" # Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines, flexible demand and candidate storage

loadprofile = 0.1 .* ones(n_loads, number_of_hours) # Create a load profile: In this case there are 5 loads in the test case
t_vec = start_hour:start_hour+(number_of_hours-1)

# Manipulate load profile: Load number 5 changes over time: Orignal load is 240 MW.
load_mod_mean = 120
load_mod_var = 120
loadprofile[i_load_mod,:] = ( load_mod_mean .+ load_mod_var .* sin.(t_vec * 2*pi/24) )/240

# Increase load on one of the days
day = 2
mins = findall(x->x==0,loadprofile)
loadprofile[mins[day-1]:mins[day]] *= 3
day = 3
loadprofile[mins[day-1]:mins[day]] *= 2.5

# Data manipulation (per unit conversions and matching data models)
data = _FP.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)
_FP.add_dimension!(data, :hour, number_of_hours)
_FP.add_dimension!(data, :year, 1)


extradata = _FP.create_profile_data(number_of_hours, data, loadprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _FP.make_multinetwork(data, extradata)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc; setting = s)

# Plot branch flows to bus 5
p_flow_1 = plot_branch_flow(result_test1,1,data,"branchdc")
p_flow_2 = plot_branch_flow(result_test1,2,data,"branchdc")
savefig(p_flow_1, joinpath(out_dir,"branch_flow_1.png"))
savefig(p_flow_2, joinpath(out_dir,"branch_flow_2.png"))

# Check if new DC branch is built and plot flow
p_flow_ne = plot_branch_flow(result_test1,3,data,"branchdc_ne")
savefig(p_flow_ne, joinpath(out_dir,"ne_branch_flow.png"))

# Check if new AC branch is built
plot_branch_flow(result_test1,1,data,"ne_branch")

# Plot exemplary (flexible) load
p_flex = plot_flex_demand(result_test1,5,data,extradata)
plot!(title = "max energy not served: 1000 MWh and max energy reduction: 100 MWh")
savefig(p_flex, joinpath(out_dir,"flex_demand_ered_1000MWh_pred_100MWh.png"))

## Espen

# get res structure overview of units and vars
res_structure = get_res_structure(result_test1)
#using PrettyPrint
#pprint(res_structure)


# Get data for unit type
bus_data = get_data(data, "bus")
busdc_data = get_data(data, "busdc")
convdc_data = get_data(data, "convdc")
load_data = get_data(data, "load")
gen_data = get_data(data, "gen")
# To get entire width of wide tables instead of only metadata use:
# using IndexedTables
# IndexedTables.set_show_compact!(false)
branch_data = get_data(data, "branch")
branchdc_data = get_data(data, "branchdc")
ne_branch_data = get_data(data, "ne_branch")
branchdc_ne_data = get_data(data, "branchdc_ne")
ne_storage_data = get_data(data, "ne_storage")


# Get snapshot (single time) variables by units
load_t1 = snapshot_utype(result_test1, "load", 1)
load_t3 = snapshot_utype(result_test1, "load", 3)
load_t8 = snapshot_utype(result_test1, "load", 8)
branch_t1 = snapshot_utype(result_test1, "branch", 1)
branchdc_t1 = snapshot_utype(result_test1, "branchdc", 1)

conv_1 = plot_res(result_test1, "convdc", "1")

plot_res(result_test1, "branchdc", "1","pt")
plot_res!(result_test1, "branchdc", "2","pt")

# Get variables per unit by times
load5 = get_res(result_test1, "load", "5")
branchdc_1 = get_res(result_test1, "branchdc", "1")
branchdc_2 = get_res(result_test1, "branchdc", "2")
branchdc_ne_3 = get_res(result_test1, "branchdc_ne", "3")

# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
stack_series = [select(branchdc_2, :pt) select(branchdc_ne_3, :pf) select(branchdc_1, :pt) select(load5, :pred) select(load5, :pcurt)]
stack_labels = ["dc branch 2" "new dc branch 3" "dc branch 1"  "reduced load" "curtailed load"]
stacked_plot = stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false)
#... lines for base and flexible demand
bus_nr = 5
load5_input = transpose(extradata["load"][string(bus_nr)]["pd"])
plot!(t_vec, load5_input, color=:red, width=3.0, label="base demand", line=:dash)
plot_res!(result_test1, "load", string(bus_nr),"pflex", label="flexible demand",
          ylabel="power (p.u.)", color=:blue, width=3.0, line=:dash, gridalpha=0.5)
#... save figure
savefig(stacked_plot, joinpath(out_dir,"bus5_balance.png"))

# Plot energy not served
plot_not_served = plot_res(result_test1, "load", "5", "ered", color=:black, width=3.0,
                           label="total energy not served", xlabel="time (h)",
                           ylabel="energy (p.u.)", legend=false, gridalpha=0.5)

# Make legend in new plot
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
savefig(vertical_plot, joinpath(out_dir,"bus5_balance_vertical.png"))

# Plot the shifted demand
stack_series = select(load5, :pshift_up)
label = "pshift_up"
plot_energy_shift = stackedarea(t_vec, stack_series,  labels=label, alpha=0.7, color=:blue, legend=false)
stack_series = select(load5, :pshift_down)*-1
label = "pshift_down"
stackedarea!(t_vec, stack_series, labels=label, xlabel="time (h)", ylabel="load shifted (p.u.)",
             alpha=0.7, color=:red, legend=false, gridalpha=0.5)

# Make legend in new plot
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
savefig(vshift_plot, joinpath(out_dir,"bus5_balance_vshift.png"))

# Plot all variables of unit
plot_res(result_test1, "load", "5")

# Plot specified list of variables of unit
shift_vars = ["pshift_down", "eshift_down", "pshift_up", "eshift_up", "pred", "pcurt", "pflex"]
plot_res(result_test1, "load", "5", shift_vars)


## Run marginal analysis with model
include("../../src/addon/marginal_analysis.jl")
include("../../test/io/get_marginal_analysis_results.jl")

m_utype = "load"
m_unit = "5"
m_param = "cost_inv"
inv_var = "flex"
#inv_var = "isbuilt"
data["branchdc_ne"]["3"]["cost"] = 3.5
marginal_param = Dict((m_utype, m_unit, m_param) => [1 10 100 1000 10000])
m_res = marginal_analysis(marginal_param, data, extradata, _PM, cbc)
data["branchdc_ne"]["3"]["cost"] = 3.5

## Plot marginal analysis results
# m_utype = "branchdc_ne"
# m_unit = "3"
# inv_var = "isbuilt"

ax_type = :log # true
m_cost = Dict()
for (k, v) in m_res
    m_cost[k] = v["objective"]
end
m_cost = sort(m_cost)
ma_linecost = plot(m_cost)
scatter!(m_cost, ylabel="Objective value", xaxis=ax_type, legend=false)
savefig(ma_linecost, joinpath(out_dir,"ma_linecost.png"))

#res_var_1 = get_res(m_res[100], m_utype, m_unit)
#res_var_1_10 = get_res(m_res[300], m_utype, m_unit)
#res_var_1_100 = get_res(m_res[500], m_utype, m_unit)
#res_var_1_1000 = get_res(m_res[700], m_utype, m_unit)
#res_var_1_10000 = get_res(m_res[900], m_utype, m_unit)


snap_res = snapshot_utype(m_res[100], m_utype, 1)

isbuilt = get_ma_results(m_res, m_utype, inv_var)

load_t1 = snapshot_utype(m_res[100], m_utype, 1)


new_dcbranches = plot_var(isbuilt, :pval, xaxis=ax_type, seriestype=:scatter,
                          xlabel=join([m_utype, " investment cost"]),
                          ylabel = join([m_utype, " built? (bool)"]),
                          legendtitle=join([m_utype, " number:"]),
                          legendtitlefontsize=8)

dcbranch_inv_plot = plot(ma_linecost, new_dcbranches, layout = @layout([A; B]),
         size=(700, 400))
savefig(dcbranch_inv_plot, joinpath(out_dir,"branch_inv_plot.png"))


## Plot results
pval = 1000
res_plot = m_res[pval]

# Get variables per unit by times
load5 = get_res(res_plot, "load", "5")
branchdc_1 = get_res(res_plot, "branchdc", "1")
branchdc_2 = get_res(res_plot, "branchdc", "2")
branchdc_ne_3 = get_res(res_plot, "branchdc_ne", "3")

# Plot combined stacked area and line plot for energy balance in bus 5
#... plot areas for power contribution from different sources
stack_series = [select(branchdc_2, :pt) select(branchdc_ne_3, :pf) select(branchdc_1, :pt) select(load5, :pred) select(load5, :pcurt)]
stack_labels = ["dc branch 2" "new dc branch 3" "dc branch 1"  "reduced load" "curtailed load"]
stacked_plot = stackedarea(t_vec, stack_series, labels= stack_labels, alpha=0.7, legend=false)
#... lines for base and flexible demand
bus_nr = 5
load5_input = transpose(extradata["load"][string(bus_nr)]["pd"])
plot!(t_vec, load5_input, color=:red, width=3.0, label="base demand", line=:dash)
plot_res!(res_plot, "load", string(bus_nr),"pflex", label="flexible demand",
          ylabel="power (p.u.)", color=:blue, width=3.0, line=:dash, gridalpha=0.5)
#... save figure
savefig(stacked_plot, joinpath(out_dir,"bus5_balance.png"))

# Plot energy not served
plot_not_served = plot_res(res_plot, "load", "5", "ered", color=:black, width=3.0,
                           label="total energy not served", xlabel="time (h)",
                           ylabel="energy (p.u.)", legend=false, gridalpha=0.5)

# Make legend in new plot
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
savefig(vertical_plot, joinpath(out_dir,"bus5_balance_$pval.png"))

# Plot the shifted demand
stack_series = select(load5, :pshift_up)
label = "pshift_up"
plot_energy_shift = stackedarea(t_vec, stack_series,  labels=label, alpha=0.7, color=:blue, legend=false)
stack_series = select(load5, :pshift_down)*-1
label = "pshift_down"
stackedarea!(t_vec, stack_series, labels=label, xlabel="time (h)", ylabel="load shifted (p.u.)",
             alpha=0.7, color=:red, legend=false, gridalpha=0.5)

# Make legend in new plot
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
savefig(vshift_plot, joinpath(out_dir,"bus5_balance_shift_$pval.png"))
