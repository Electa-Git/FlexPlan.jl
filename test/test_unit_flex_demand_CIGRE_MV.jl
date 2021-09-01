# UNIT TEST SCRIPT to run multi-period optimisation of demand flexibility for the CIGRE MV benchmark network
# (It should reproduce the situation shown in Fig. 55 in D1.2 where flexibility is activated and no new line is built.)

include("io/read_case_data_from_csv.jl")

# Input parameters:
number_of_hours = 72          # Number of time steps
n_loads = 13                  # Number of load points
start_hour = 1                # First time step
load_scaling_factor = 0.8       # Factor with which original base case load demand data should be scaled

# Vector of hours (time steps) included in case
t_vec = start_hour:start_hour+(number_of_hours-1)

# Input case, in matpower m-file format: Here CIGRE MV benchmark network
file = normpath(@__DIR__,"..","test","data","CIGRE_MV_benchmark_network_flex.m")

# Filename with extra_load array with demand flexibility model parameters
filename_load_extra = normpath(@__DIR__,"..","test","data","CIGRE_MV_benchmark_network_flex_load_extra.csv")

# Create PowerModels data dictionary (AC networks and storage)
data = _PM.parse_file(file)
_FP.add_dimension!(data, :hour, number_of_hours)

# Handle possible missing auxiliary fields of the MATPOWER case file
field_names = ["busdc","busdc_ne","branchdc","branchdc_ne","convdc","convdc_ne","ne_storage","storage","storage_extra"]
for field_name in field_names
      if !haskey(data,field_name)
            data[field_name] = Dict{String,Any}()
      end
end

# Read load demand series and assign (relative) profiles to load points in the network
data,loadprofile,genprofile = create_profile_data_norway(data, number_of_hours)

# Add extra_load array for demand flexibility model parameters
data = read_case_data_from_csv(data,filename_load_extra,"load_extra")

# Scale load at all of the load points
for i_load = 1:n_loads
      data["load"][string(i_load)]["pd"] = data["load"][string(i_load)]["pd"] * load_scaling_factor
      data["load"][string(i_load)]["qd"] = data["load"][string(i_load)]["qd"] * load_scaling_factor
end

# Add flexible data model
_FP.add_flexible_demand_data!(data)

# create a dictionary to pass time series data to data dictionary
extradata = _FP.create_profile_data(number_of_hours, data, loadprofile)

# Create data dictionary where time series data is included at the right place
mn_data = _FP.make_multinetwork(data, extradata)

# Build optimisation model, solve it and write solution dictionary:
s = Dict("output" => Dict("branch_flows" => true))
result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc, multinetwork=true; setting = s)

# Test solution against benchmark solution
@testset "Flexible TNEP distribution" begin
    @testset "CIGRE MV benchmark network demand flexibility" begin
        @test isapprox(result["objective"], 84.390, atol = 1e-3)
        @test isapprox(result["solution"]["nw"]["1"]["ne_branch"]["1"]["built"],0.0, atol = 1e-1)
        @test isapprox(result["solution"]["nw"]["1"]["ne_branch"]["2"]["built"],0.0, atol = 1e-1)
        @test isapprox(result["solution"]["nw"]["68"]["load"]["2"]["pnce"], 0.0180421, atol = 1e-5)
        @test isapprox(result["solution"]["nw"]["72"]["load"]["2"]["pshift_down_tot"], 0.2166877, atol = 1e-5)
    end
end

