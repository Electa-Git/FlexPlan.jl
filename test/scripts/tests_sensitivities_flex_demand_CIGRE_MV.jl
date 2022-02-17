# Script for sensitivity analysis for investment decisions in CIGRE MV benchmark network

# Import relevant pakcages:
import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import IndexedTables; const _IT = IndexedTables
using Plots

include("../io/create_profile.jl")
include("../io/read_case_data_from_csv.jl")

# Add solver packages
import JuMP
import Cbc

# Solver configurations
cbc = JuMP.with_optimizer(Cbc.Optimizer, tol=1e-4, seconds=20, print_level=0)


# Input parameters:
number_of_hours = 72          # Number of time steps
start_hour = 1                # First time step
n_loads = 13                  # Number of load points
use_DC = false                              # True for using DC power flow model; false for using linearized power real-reactive flow model for radial networks

# Values for sensitivity analysis of factor with which original base case load demand data should be scaled
vec_load_scaling_factor = [0.8 0.825 0.85 0.875 0.9 0.925 0.95 0.975 1.0]
#vec_load_scaling_factor = [0.8 0.85 0.9 0.95 1.0]

# Values for sensitivity analysis of pshift_down and pshift_up (demand flexibility potential)
vec_pshift_max = [0.0 0.1 0.2 0.3]
#vec_pshift_max = [0.0]

# Values for sensitivity analysis of tshift_down and tshift_up (demand flexibility recovery period)
vec_tshift = [2 6 10]
#vec_tshift = [2]

# Vector of hours (time steps) included in case
t_vec = start_hour:start_hour + (number_of_hours - 1)

# Input case, in matpower m-file format: Here CIGRE MV benchmark network
file = "./test/data/CIGRE_MV_benchmark_network_flex.m"

# Filename with extra_load array with demand flexibility model parameters
filename_load_extra = "./test/data/CIGRE_MV_benchmark_network_flex_load_extra.csv"


# Matrix for results of the sensitivity analysis: How many branches have to be built
n_load_scaling_factor = length(vec_load_scaling_factor)
n_pshift_max = length(vec_pshift_max)
n_tshift = length(vec_tshift)
n_branches_built = zeros(n_load_scaling_factor, n_pshift_max, n_tshift)

# Sensitivity analysis for load scaling factor
for i_load_scaling_factor = 1:n_load_scaling_factor

    # Sensitivity analysis for demand flexibility potential
    for i_pshift_max = 1:n_pshift_max

        # Sensitivity analysis for recovery period
        for i_tshift = 1:n_tshift

            # Data manipulation (per unit conversions and matching data models)
            data = _PM.parse_file(file)  # Create PowerModels data dictionary (AC networks and storage)

            # Handle possible missing auxiliary fields of the MATPOWER case file
            field_names = ["busdc","busdc_ne","branchdc","branchdc_ne","convdc","convdc_ne","ne_storage","storage","storage_extra"]
            for field_name in field_names
                if !haskey(data, field_name)
                    data[field_name] = Dict{String,Any}()
                end
            end

            # Read load demand series and assign (relative) profiles to load points in the network
            data, loadprofile, genprofile = create_profile_data_norway(data, number_of_hours)

            # Add extra_load array for demand flexibility model parameters
            data = read_case_data_from_csv(data, filename_load_extra, "load_extra")

            if use_DC
                _PMACDC.process_additional_data!(data) # Add DC grid data to the data dictionary
            end
            _FP.add_flexible_demand_data!(data) # Add flexible data model

            # Scale load at all of the load points
            for i_load = 1:n_loads
                data["load"][string(i_load)]["pd"] = data["load"][string(i_load)]["pd"] * vec_load_scaling_factor[i_load_scaling_factor]
                data["load"][string(i_load)]["qd"] = data["load"][string(i_load)]["qd"] * vec_load_scaling_factor[i_load_scaling_factor]
            end

            # Update demand flexibility parameter values for all load points
            for i_load = 1:n_loads
                data["load"][string(i_load)]["tshift_down"] = vec_tshift[i_tshift]
                data["load"][string(i_load)]["tshift_up"] = vec_tshift[i_tshift]
                data["load"][string(i_load)]["pshift_down_rel_max"] = vec_pshift_max[i_pshift_max]
                data["load"][string(i_load)]["pshift_up_rel_max"] = vec_pshift_max[i_pshift_max]
            end

            extradata = create_profile_data(number_of_hours, data, loadprofile) # create a dictionary to pass time series data to data dictionary
            # Create data dictionary where time series data is included at the right place
            mn_data = _FP.make_multinetwork(data, extradata)

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
            if use_DC
                results = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, cbc; setting=s)
            else
                results = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc; setting=s)
            end

            # Finding number of branches that are built
            n_branches_built_this = 0;
            n_ne_branches = length(results["solution"]["nw"]["1"]["ne_branch"])

            for i_ne_branch = 1:n_ne_branches
                n_branches_built_this += results["solution"]["nw"]["1"]["ne_branch"][string(i_ne_branch)]["built"]
            end
            n_branches_built[i_load_scaling_factor,i_pshift_max,i_tshift] = n_branches_built_this

        end
    end
end