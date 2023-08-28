# Test IO functions provided by files in `src/io/`

@testset "Input-ouput" begin

    # case6:
    # - investments: AC branches, converters, DC branches, storage;
    # - generators: with `pg>0`, non-dispatchable with `pcurt>0`;
    case6_data = load_case6(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_gen=13, share_data=false)
    case6_result = _FP.simple_stoch_flex_tnep(case6_data, _PM.DCPPowerModel, milp_optimizer; setting=Dict("conv_losses_mp"=>false))

    # ieee_33:
    # - investments: AC branches, storage, flexible loads;
    # - flexible loads: shift up, shift down, voluntary reduction, curtailment.
    ieee_33_data = load_ieee_33(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_load=1.52, share_data=false)
    ieee_33_result = _FP.simple_stoch_flex_tnep(ieee_33_data, _FP.BFARadPowerModel, milp_optimizer)

    @testset "scale_data!" begin

        @testset "cost_scale_factor" begin
            scale_factor = 1e-6

            data = load_case6(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_gen=13, cost_scale_factor=scale_factor)
            result_scaled = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, milp_optimizer; setting=Dict("conv_losses_mp"=>false))
            @test result_scaled["objective"] ≈ scale_factor*case6_result["objective"] rtol=1e-5

            data = load_ieee_33(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_load=1.52, cost_scale_factor=scale_factor)
            result_scaled = _FP.simple_stoch_flex_tnep(data, _FP.BFARadPowerModel, milp_optimizer)
            @test result_scaled["objective"] ≈ scale_factor*ieee_33_result["objective"] rtol=1e-5
        end
    end

    @testset "convert_mva_base!" begin
        for mva_base_ratio in [0.01, 100]
            data = deepcopy(case6_data)
            mva_base = data["nw"]["1"]["baseMVA"] * mva_base_ratio
            _FP.convert_mva_base!(data, mva_base)
            result = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, milp_optimizer; setting=Dict("conv_losses_mp"=>false))
            @test result["objective"] ≈ case6_result["objective"] rtol=1e-5

            data = deepcopy(ieee_33_data)
            mva_base = data["nw"]["1"]["baseMVA"] * mva_base_ratio
            _FP.convert_mva_base!(data, mva_base)
            result = _FP.simple_stoch_flex_tnep(data, _FP.BFARadPowerModel, milp_optimizer)
            @test result["objective"] ≈ ieee_33_result["objective"] rtol=1e-5
        end
    end

end;
