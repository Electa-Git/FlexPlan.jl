# TEST SCRIPT to run multi-period optimisation of demand flexibility, AC & DC lines and storage investments 

# Input parameters:
number_of_hours = 96        # Number of time steps
start_hour = 1              # First time step
n_loads = 5                 # Number of load points
i_load_mod = 5              # The load point on which we modify the demand profile


file = normpath(@__DIR__,"..","test","data","case6_flex.m")
#file = "test/data/case6_flex.m" # Input case, in matpower m-file format: Here 6bus case with candidate AC, DC lines, flexible demand and candidate storage

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
data = _PM.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)
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

@testset "Flexible TNEP" begin
    @testset "6-bus all candidates" begin
        @test isapprox(result_test1["objective"], 1281.5, atol = 1e-1)
        @test isapprox(result_test1["solution"]["nw"]["1"]["ne_storage"]["1"]["isbuilt"], 0, atol = 1e-1)
        @test isapprox(result_test1["solution"]["nw"]["1"]["ne_branch"]["1"]["built"], 0, atol = 1e-1)
        @test isapprox(result_test1["solution"]["nw"]["1"]["convdc_ne"]["6"]["isbuilt"], 1.0, atol = 1e-1)
        @test isapprox(result_test1["solution"]["nw"]["1"]["load"]["5"]["pshift_up"], 0.453175, atol = 1e-1)
        @test isapprox(result_test1["solution"]["nw"]["17"]["load"]["5"]["pflex"], 0.040889, atol = 1e-2)
        @test isapprox(result_test1["solution"]["nw"]["56"]["load"]["5"]["ence"], 9.29585, atol = 1e-2)
    end
end