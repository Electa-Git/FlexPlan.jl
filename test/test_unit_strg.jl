# use non-commercial solver so that tests can run on any machine
#cbc = JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)

dim = 4 # Number of time points
cd(dirname(@__FILE__)) # set working directory to file directory
file = "./data/case6_strg.m"

# Test 1: constant demand at all loads (base case)
data = _FP.parse_file(file; flex_load=false)
_FP.add_dimension!(data, :hour, dim)
_FP.add_dimension!(data, :year, 1)

loadprofile = ones(5, dim)

extradata = _FP.create_profile_data(dim, data, loadprofile)
mn_data = _FP.make_multinetwork(data, extradata)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

result_test1 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# Test 1: several DC lines should be built to meet the constant demand at loads, no storage
@testset "Storage first test (TNEP with constant demand at loads)" begin
    nw = result_test1["solution"]["nw"]["1"]
    for (key, value) in nw["branchdc_ne"]
        if key in ["9"] # only DC line 9 should be built
            @test nw["branchdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw["branchdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw["convdc_ne"]
        if key in ["4", "6"]  # converters 4 and 6 should be built
            @test nw["convdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw["convdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw["ne_branch"]
        if key in ["1"]  # AC line 1 should be built
            @test nw["ne_branch"][key]["built"] == 1.0
        else
            @test nw["ne_branch"][key]["built"] == 0.0
        end
    end
    for (key, value) in nw["ne_storage"]
        if key in []  # no storage should be built
            @test nw["ne_storage"][key]["isbuilt"] == 1.0
        else
            @test nw["ne_storage"][key]["isbuilt"] == 0.0
        end
    end

    # existing storage not used at all since constant demand and generation
    @test nw["storage"]["1"]["e_abs"] == 0
end

# Test 2: variable demand at bus 5: [100, 100, 100 , 240] MW over time
data = _FP.parse_file(file; flex_load=false)
_FP.add_dimension!(data, :hour, dim)
_FP.add_dimension!(data, :year, 1)
loadprofile = ones(5, dim)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))

extradata = _FP.create_profile_data(dim, data, loadprofile)
mn_data = _FP.make_multinetwork(data, extradata)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

result_test2 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# Test 2: existing storage at bus 5 should be used to charge in 3 time steps and then discharge at step 4,
#         less line investments need to be performed
@testset "Storage second test (TNEP with variable demand)" begin
    nw1 = result_test2["solution"]["nw"]["1"]
    for (key, value) in nw1["branchdc_ne"]
        if key in ["9"] # only DC line 9 should be built
            @test nw1["branchdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["branchdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["convdc_ne"]
        if key in ["4", "6"]  # converters 4 and 6 should be built
            @test nw1["convdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["convdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["ne_branch"]
        if key in []  # no AC line should be built
            @test nw1["ne_branch"][key]["built"] == 1.0
        else
            @test nw1["ne_branch"][key]["built"] == 0.0
        end
    end
    for (key, value) in nw1["ne_storage"]
        if key in []  # no storage should be built
            @test nw1["ne_storage"][key]["isbuilt"] == 1.0
        else
            @test nw1["ne_storage"][key]["isbuilt"] == 0.0
        end
    end

    nw3 = result_test2["solution"]["nw"]["3"]
    nw4 = result_test2["solution"]["nw"]["4"]

    # at step 3 storage should have accumulated enough energy to cover residual demand at load 5 in step 4
    @test nw3["storage"]["1"]["se"] ≈ (0.8/data["storage"]["1"]["discharge_efficiency"]) atol=0.01
    @test nw4["storage"]["1"]["sd"] ≈ 0.8 atol=0.01

end

# Test 3: Existing storage is out of service ("status" = 0) to push the construction of a new storage asset
data = _FP.parse_file(file; flex_load=false)
_FP.add_dimension!(data, :hour, dim)
_FP.add_dimension!(data, :year, 1)
data["storage"]["1"]["status"] = 0 # take existing storage out of service
loadprofile = ones(5, dim)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))

extradata = _FP.create_profile_data(dim, data, loadprofile)
mn_data = _FP.make_multinetwork(data, extradata)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)
result_test3 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# Test 3: the results should stay the same than in Test 2 except that a new storage is built at bus 5 to replace
#         the deactivted storage asset
@testset "Storage third test (TNEP with storage dectivated)" begin
    nw1 = result_test3["solution"]["nw"]["1"]
    for (key, value) in nw1["branchdc_ne"]
        if key in ["9"] # only DC line 9 should be built
            @test nw1["branchdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["branchdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["convdc_ne"]
        if key in ["4", "6"]  # converters 4 and 6 should be built
            @test nw1["convdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["convdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["ne_branch"]
        if key in []  # no AC line should be built
            @test nw1["ne_branch"][key]["built"] == 1.0
        else
            @test nw1["ne_branch"][key]["built"] == 0.0
        end
    end
    for (key, value) in nw1["ne_storage"]
        if key in ["1"]  # candidate storage at node 5 should be built
            @test nw1["ne_storage"][key]["isbuilt"] == 1.0
        else
            @test nw1["ne_storage"][key]["isbuilt"] == 0.0
        end
    end

    nw3 = result_test3["solution"]["nw"]["3"]
    nw4 = result_test3["solution"]["nw"]["4"]

    # at step 3 storage should have accumulated enough energy to cover residual demand at load 5 in step 4
    @test nw3["ne_storage"]["1"]["se_ne"] ≈ (0.8/data["ne_storage"]["1"]["discharge_efficiency"]) atol=0.01
    @test nw4["ne_storage"]["1"]["sd_ne"] ≈ 0.8 atol=0.01
end

# Test 4: existing storage is still deaactivated, an additional storage investment candidate is added
#         with a smaller energy rating and a lower cost
data = _FP.parse_file(file; flex_load=false)
_FP.add_dimension!(data, :hour, dim)
_FP.add_dimension!(data, :year, 1)
data["storage"]["1"]["status"] = 0 # take existing storage out of service
data["ne_storage"]["2"] = copy(data["ne_storage"]["1"]) # create new candidate
data["ne_storage"]["2"]["index"] = 2
# new candidate has lower energy_rating and lower cost
data["ne_storage"]["2"]["energy_rating"] = 2.0
data["ne_storage"]["2"]["eq_cost"] = 1.0
loadprofile = ones(5, dim)
loadprofile[end, :] = repeat([100 100 100 240] / 240, 1 , Int(dim /4))

extradata = _FP.create_profile_data(dim, data, loadprofile)
mn_data = _FP.make_multinetwork(data, extradata)

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

result_test4 = _FP.strg_tnep(mn_data, _PM.DCPPowerModel, cbc, multinetwork=true; setting = s)

# Test 4: results should stay the same than in Test 3 except that a the smaller and cheaper storage
#         is built
@testset "Storage fourth test (TNEP with second storage candidate)" begin
    nw1 = result_test4["solution"]["nw"]["1"]
    for (key, value) in nw1["branchdc_ne"]
        if key in ["9"] # only DC line 9 should be built
            @test nw1["branchdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["branchdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["convdc_ne"]
        if key in ["4", "6"]  # converters 4 and 6 should be built
            @test nw1["convdc_ne"][key]["isbuilt"] == 1.0
        else
            @test nw1["convdc_ne"][key]["isbuilt"] == 0.0
        end
    end
    for (key, value) in nw1["ne_branch"]
        if key in []  # no AC line should be built
            @test nw1["ne_branch"][key]["built"] == 1.0
        else
            @test nw1["ne_branch"][key]["built"] == 0.0
        end
    end
    for (key, value) in nw1["ne_storage"]
        if key in ["2"]  # only the 2nd candidate should be built
            @test nw1["ne_storage"][key]["isbuilt"] == 1.0
        else
            @test nw1["ne_storage"][key]["isbuilt"] == 0.0
        end
    end

    nw3 = result_test4["solution"]["nw"]["3"]
    nw4 = result_test4["solution"]["nw"]["4"]

    # at step 3 storage should have accumulated enough energy to cover residual demand at load 5 in step 4
    @test nw3["ne_storage"]["2"]["se_ne"] ≈ (0.8/data["ne_storage"]["2"]["discharge_efficiency"]) atol=0.01
    @test nw4["ne_storage"]["2"]["sd_ne"] ≈ 0.8 atol=0.01
end;
