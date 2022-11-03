# Test problem functions

# The purpose of the tests contained in this file is to detect if anything has accidentally
# changed in the problem functions. Accordingly, only the termination status and the
# objective value are tested.
# To test specific features, it is better to write ad-hoc tests in other files.

@testset "Problem" begin

    t_data = load_case6(;
        number_of_hours = 4,
        number_of_scenarios = 2,
        number_of_years = 3,
        cost_scale_factor = 1e-6
    )
    t_data_1scenario = _FP.slice_multinetwork(t_data; scenario=1)
    setting = Dict("conv_losses_mp" => false)

    d_data = load_cigre_mv_eu(; # TODO: use a test case with multiple years and scenarios when available.
        flex_load = true,
        ne_storage = true,
        scale_load = 6.0,
        number_of_hours = 4,
        cost_scale_factor = 1e-6
    )

    @testset "TNEP without flex loads" begin
        @testset "Transmission" begin
            result = _FP.strg_tnep(t_data_1scenario, _PM.DCPPowerModel, milp_optimizer; setting)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 7489.8 rtol=1e-3
        end
        @testset "Distribution" begin
            result = _FP.strg_tnep(d_data, _FP.BFARadPowerModel, milp_optimizer)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 355.0 rtol=1e-3
        end
    end

    @testset "TNEP" begin
        @testset "Transmission" begin
            result = _FP.flex_tnep(t_data_1scenario, _PM.DCPPowerModel, milp_optimizer; setting)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 7486.2 rtol=1e-3
        end
        @testset "Distribution" begin
            result = _FP.flex_tnep(d_data, _FP.BFARadPowerModel, milp_optimizer)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 354.6 rtol=1e-3
        end
    end

    @testset "Stochastic TNEP" begin
        @testset "Transmission" begin
            result = _FP.stoch_flex_tnep(t_data, _PM.DCPPowerModel, milp_optimizer; setting)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 7702.3 rtol=1e-3
        end
        @testset "Distribution" begin
            result = _FP.stoch_flex_tnep(d_data, _FP.BFARadPowerModel, milp_optimizer)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 354.6 rtol=1e-3
        end
    end

    @testset "Simplified stochastic TNEP" begin
        @testset "Transmission" begin
            result = _FP.simple_stoch_flex_tnep(t_data, _PM.DCPPowerModel, milp_optimizer; setting)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 7617.5 rtol=1e-3
        end
        @testset "Distribution" begin
            result = _FP.simple_stoch_flex_tnep(d_data, _FP.BFARadPowerModel, milp_optimizer)
            @test result["termination_status"] == OPTIMAL
            @test result["objective"] ≈ 354.6 rtol=1e-3
        end
    end

end;
