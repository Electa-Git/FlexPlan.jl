# Import relevant pakcages:
# FlexPlan uses PowerModelsACDC for the multi-period transmission expansion optimisation & DC grid
# PowerModelsACDC uses PowerModels for the AC grid, and the optimisation create_profile_data
# InfrastructureModels is needed for data manipulation and common functions
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels

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
import CPLEX
import JSON
import CSV

# Solver configurations
scs = JuMP.with_optimizer(SCS.Optimizer, max_iters=100000)
ipopt = JuMP.with_optimizer(Ipopt.Optimizer, tol=1e-4, print_level=0)
cplex = JuMP.with_optimizer(CPLEX.Optimizer)
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, print_level=0)
gurobi = JuMP.with_optimizer(Gurobi.Optimizer)
mosek = JuMP.with_optimizer(Mosek.Optimizer)
juniper = JuMP.with_optimizer(Juniper.Optimizer, nl_solver = ipopt, mip_solver= cbc, time_limit= 7200)

# Read in renewable generation and demand profile data
#pv_sicily, pv_south_central, wind_sicily = _FP.read_res_and_demand_data()
pv_sicily = Dict()
open("./test/data/pv_sicily.json") do f
    global pv_sicily
    dicttxt = read(f, String)  # file information to string
    pv_sicily = JSON.parse(dicttxt)  # parse and transform data
end
pv_south_central = Dict()
open("./test/data/pv_south_central.json") do f
    global pv_south_central
    dicttxt = read(f, String)  # file information to string
    pv_south_central = JSON.parse(dicttxt)  # parse and transform data
end

wind_sicily = Dict()
open("./test/data/wind_sicily.json") do f
    global wind_sicily
    dicttxt = read(f, String)  # file information to string
    wind_sicily = JSON.parse(dicttxt)  # parse and transform data
end

demand_north = convert(Matrix, CSV.read("./test/data/demand_north.csv"))[:,3]
demand_center_north = convert(Matrix, CSV.read("./test/data/demand_center_north.csv"))[:,3]
demand_center_south = convert(Matrix, CSV.read("./test/data/demand_center_south.csv"))[:,3]
demand_south = convert(Matrix, CSV.read("./test/data/demand_south.csv"))[:,3]
demand_sardinia = convert(Matrix, CSV.read("./test/data/demand_sardinia.csv"))[:,3]

demand_north_pu = demand_north ./ maximum(demand_north)
demand_center_north_pu = demand_north ./ maximum(demand_center_north)
demand_south_pu = demand_south ./ maximum(demand_south)
demand_center_south_pu = demand_center_south ./ maximum(demand_center_south)
demand_sardinia_pu = demand_sardinia ./ maximum(demand_sardinia)

# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments 
# Input parameters
start_hour = 1546300800000   # 01.01.2019:00:00 in epoch time
number_of_hours = 4 # Number of time points

file = "./test/data/case6_all_candidates.m"  #Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines and candidate storage


# Test 1: Line vs storage: Base case Load at bus 5 [240, 240, 240 , 240] MW over time
data = _PM.parse_file(file) # Create PowerModels data dictionary (AC networks and storage)

data["bus"]["1"]["lat"] = 43.4894; data["bus"]["1"]["lon"] =  11.7946; #Italy central north
data["bus"]["2"]["lat"] = 45.3411; data["bus"]["2"]["lon"] =  9.9489;  #Italy north
data["bus"]["3"]["lat"] = 41.8218; data["bus"]["3"]["lon"] =   13.8302; #Italy central south
data["bus"]["4"]["lat"] = 40.5228; data["bus"]["4"]["lon"] =   16.2155; #Italy south
data["bus"]["5"]["lat"] = 40.1717; data["bus"]["5"]["lon"] =   9.0738; # Sardinia
data["bus"]["6"]["lat"] = 37.4844; data["bus"]["6"]["lon"] =   14.1568; # Sicily

genprofile = ones(length(data["gen"]), number_of_hours)
for h in 1 : number_of_hours
    h_idx = start_hour + ((h-1) * 3600000)
    genprofile[3, h] = pv_south_central["data"]["$h_idx"]["electricity"]
    genprofile[5, h] = pv_sicily["data"]["$h_idx"]["electricity"]
    genprofile[6, h] = wind_sicily["data"]["$h_idx"]["electricity"]
end
loadprofile = [demand_center_north_pu'; demand_north_pu'; demand_center_south_pu'; demand_south_pu'; demand_sardinia_pu'][:, 1: number_of_hours]

_PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
_FP.add_storage_data!(data) # Add addtional storage data model
_FP.add_flexible_demand_data!(data) # Add flexible data model
extradata = _FP.create_profile_data(number_of_hours, data, loadprofile, genprofile) # create a dictionary to pass time series data to data dictionary
# Create data dictionary where time series data is included at the right place
mn_data = _PMACDC.multinetwork_data(data, extradata, Set{String}(["source_type", "name", "source_version", "per_unit"]))

plot_settings = Dict("add_nodes" => true, "plot_result_only" => false)
plot_filename = "./test/data/output_files/test_plot.kml"

_FP.plot_geo_data(mn_data, plot_filename, plot_settings)

# Add PowerModels(ACDC) settings
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
# Build optimisation model, solve it and write solution dictionary:
# This is the "problem file" which needs to be constructed individually depending on application
# In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments

result_test1 = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, gurobi, multinetwork=true; setting = s)


plot_settings = Dict("add_nodes" => true, "plot_solution_only" => true)
plot_filename = "./test/data/output_files/test_plot_result.kml"
_FP.plot_geo_data(mn_data, plot_filename, plot_settings; solution = result_test1)