# Test problem functions

# The purpose of the tests contained in this file is to detect if anything has accidentally
# changed in the problem functions. Accordingly, only the termination status and the
# objective value are tested.
# To test specific features, it is better to write ad-hoc tests in other files.

@testset "Problem" begin

    data = create_multi_year_network_data("case6", 4, 2, 3; cost_scale_factor=1e-6)
    data_1scenario = _FP.slice_multinetwork(data; scenario=1)
    setting = Dict("conv_losses_mp" => false)

    @testset "TNEP without flex loads" begin
        result = _FP.strg_tnep(data_1scenario, _PM.DCPPowerModel, cbc; setting)
        @test result["termination_status"] == _PM.OPTIMAL
        @test result["objective"] ≈ 7489.8 rtol=1e-3
    end

    @testset "TNEP" begin
        result = _FP.flex_tnep(data_1scenario, _PM.DCPPowerModel, cbc; setting)
        @test result["termination_status"] == _PM.OPTIMAL
        @test result["objective"] ≈ 7486.2 rtol=1e-3
    end

    @testset "Stochastic TNEP" begin
        result = _FP.stoch_flex_tnep(data, _PM.DCPPowerModel, cbc; setting)
        @test result["termination_status"] == _PM.OPTIMAL
        @test result["objective"] ≈ 7702.3 rtol=1e-3
    end

    @testset "Simplified stochastic TNEP" begin
        result = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, cbc; setting)
        @test result["termination_status"] == _PM.OPTIMAL
        @test result["objective"] ≈ 7617.5 rtol=1e-3
    end

end;