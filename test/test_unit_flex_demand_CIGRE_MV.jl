# UNIT TEST SCRIPT to run multi-period optimisation of demand flexibility for the CIGRE MV benchmark network
# (It should reproduce the situation shown in Fig. 55 in D1.2 where flexibility is activated and no new line is built.)

include("io/read_case_data_from_csv.jl")

# Input parameters:
number_of_hours = 72          # Number of time steps
n_loads = 13                  # Number of load points
start_hour = 1                # First time step
load_scaling_factor = 0.69    # Factor with which original base case load demand data should be scaled

# Vector of hours (time steps) included in case
t_vec = start_hour:start_hour+(number_of_hours-1)

# Input case, in matpower m-file format: Here CIGRE MV benchmark network
file = normpath(@__DIR__,"..","test","data","CIGRE_MV_benchmark_network_flex.m")

# Filename with extra_load array with demand flexibility model parameters
filename_load_extra = normpath(@__DIR__,"..","test","data","CIGRE_MV_benchmark_network_flex_load_extra.csv")

# Create data dictionary (AC networks and storage)
data = _FP.parse_file(file; flex_load=false)

# Add extra_load table for demand flexibility model parameters
data = read_case_data_from_csv(data,filename_load_extra,"load_extra")

# Add flexible data model (required because we loaded `extra_load` separately from a csv; otherwise `_FP.parse_file` would be sufficient)
_FP.add_flexible_demand_data!(data)

# Scale load at all of the load points
for i = 1:n_loads
    data["load"]["$i"]["pd"] *= load_scaling_factor
    data["load"]["$i"]["qd"] *= load_scaling_factor
end

_FP.add_dimension!(data, :hour, number_of_hours)
_FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))

_FP.scale_data!(data)

# Read load demand series and assign (relative) profiles to load points in the network
data,loadprofile,genprofile = create_profile_data_norway(data, number_of_hours)

# Create a dictionary to pass time series data to data dictionary
extradata = _FP.create_profile_data(number_of_hours, data, loadprofile)

# Create data dictionary where time series data is included at the right place
mn_data = _FP.make_multinetwork(data, extradata)

# Build optimisation model, solve it and write solution dictionary:
s = Dict("output" => Dict("branch_flows" => true))
result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc; setting = s)
#@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"

#_PM.print_summary(result["solution"]["nw"]["68"])

# Test solution against benchmark solution
@testset "Flexible TNEP distribution" begin
    @testset "CIGRE MV benchmark network demand flexibility" begin
        @test result["objective"] ≈ 86.23540694350396 rtol=1e-4
        @test result["solution"]["nw"]["1"]["ne_branch"]["1"]["built"] ≈ 0.0 atol=1e-1
        @test result["solution"]["nw"]["1"]["ne_branch"]["2"]["built"] ≈ 0.0 atol=1e-1
        @test result["solution"]["nw"]["68"]["load"]["9"]["pnce"] ≈ 0.004652080014302931 rtol=1e-3
        @test result["solution"]["nw"]["72"]["load"]["2"]["pshift_down_tot"] ≈ 0.026483113121855778 rtol=1e-3
    end
end
