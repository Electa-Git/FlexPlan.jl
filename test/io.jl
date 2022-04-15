# Test IO functions provided by files in `src/io/`

@testset "Input-ouput" begin

    @testset "scale_data!" begin

        @testset "cost_scale_factor" begin
            scale_factor = 1e-6

            # Test costs related to:
            # - investments: AC branches, converters, DC branches, storage;
            # - generators: with `pg>0`, non-dispatchable with `pcurt>0`;
            data = load_case6(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_gen=13)
            result_unscaled = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, cbc; setting=Dict("output"=>Dict("branch_flows"=>true),"conv_losses_mp"=>false))
            data = load_case6(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_gen=13, cost_scale_factor=scale_factor)
            result_scaled = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, cbc; setting=Dict("output"=>Dict("branch_flows"=>true),"conv_losses_mp"=>false))
            @test result_scaled["objective"] ≈ scale_factor*result_unscaled["objective"] rtol=1e-5

            # Test costs related to:
            # - investments: AC branches, storage, flexible loads;
            # - flexible loads: shift up, shift down, voluntary reduction, curtailment.
            data = load_ieee_33(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_load=1.52)
            result_unscaled = _FP.simple_stoch_flex_tnep(data, _FP.BFARadPowerModel, cbc)
            data = load_ieee_33(number_of_hours=4, number_of_scenarios=1, number_of_years=1, scale_load=1.52, cost_scale_factor=scale_factor)
            result_scaled = _FP.simple_stoch_flex_tnep(data, _FP.BFARadPowerModel, cbc)
            @test result_scaled["objective"] ≈ scale_factor*result_unscaled["objective"] rtol=1e-5
        end
    end

end;
