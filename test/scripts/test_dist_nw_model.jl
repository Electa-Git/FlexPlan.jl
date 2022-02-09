# Base case to test the distribution network model.
#
# Runs a single-period problem without storage and flexible loads.
# Uses the original CIGRE network with the following changes:
# - added generator cost: all have equal prices, HV grid exchanges cost twice;
# - a fixed 1.0 tap ratio is assigned to the transformer of branch 17;
# - added some candidate branches.


## Import packages and choose a solver

import PowerModels; const _PM = PowerModels
import FlexPlan; const _FP = FlexPlan
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)


## Settings

bus_1_voltage_fixed        = false
gen_7_power_reactive_fixed = false
branch_1_impedance_zeroed  = false
branch_12_rating_zeroed    = false
branch_16_tap_ratio_fixed  = false
load_bus_1_big             = false
load_bus_12_big            = false
load_bus_13_big            = false
load_bus_14_big            = false

result_file = "test/data/output_files/test_dist_nw_model_result.txt"


## Load and preprocess data

data_file = "test/data/CIGRE_MV_benchmark_network_tnep.m"
data = _PM.parse_file(data_file)
data["ne_storage"] = Dict{String,Any}() # ne_storage is not added automatically by parse_file, but is required by strg_tnep()
_FP.add_dimension!(data, :hour, 1)
_FP.add_dimension!(data, :year, 1)
data = _FP.make_multinetwork(data)


## Apply changes for testing purpose

branch = data["nw"]["1"]["branch"]
bus    = data["nw"]["1"]["bus"]
gen    = data["nw"]["1"]["gen"]
load   = data["nw"]["1"]["load"]
if bus_1_voltage_fixed
    bus["1"]["vmin"] = 1.0
    bus["1"]["vmax"] = 1.0
end
if gen_7_power_reactive_fixed
    gen["7"]["qmin"] = 0.0
    gen["7"]["qmax"] = 0.0
end
if branch_1_impedance_zeroed
    branch["1"]["br_r"] = 0.0
    branch["1"]["br_x"] = 0.0
end
if branch_12_rating_zeroed
    branch["12"]["rate_a"] = 0.0
    branch["12"]["rate_b"] = 0.0
    branch["12"]["rate_c"] = 0.0
end
if branch_16_tap_ratio_fixed
    branch["16"]["tm_min"] = 0.95
    branch["16"]["tap"]    = 0.95
    branch["16"]["tm_max"] = 0.95
end
if load_bus_1_big
    load["1"]["pd"] += 10.0
end
if load_bus_12_big
    load["11"]["pd"] += 10.0
end
if load_bus_13_big
    load["12"]["pd"] += 8.0
end
if load_bus_14_big
    load["13"]["pd"] += 1.0
end


## Solve problem

result = _FP.strg_tnep(data, _FP.BFARadPowerModel, optimizer)
# Two-step alternative
#pm = _PM.instantiate_model(data, _FP.BFARadPowerModel, _FP.post_strg_tnep; ref_extensions=[ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!])
#result = _PM.optimize_model!(pm; optimizer, solution_processors=[_PM.sol_data_model!])
@assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"


## Write result

_PM.print_summary(result["solution"]["nw"]["1"])
mkpath(dirname(result_file))
open(result_file, "w") do io
    _PM.summary(io, result["solution"]["nw"]["1"])
end


## Perform other unit tests

gen = result["solution"]["nw"]["1"]["gen"]

pg = sum(g["pg"] for g in values(gen))
pd = sum(l["pd"] for l in values(load))
@assert pg ≈ pd "generated active power ($pg) does not match demand ($pd)"

qg = sum(g["qg"] for g in values(gen))
qd = sum(l["qd"] for l in values(load))
@assert qg ≈ qd "generated reactive power ($qg) does not match demand ($qd)"
