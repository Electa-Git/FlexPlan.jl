# Test decoupling of transmission and distribution networks

@testset "T&D decoupling" begin

    number_of_hours = 4
    number_of_distribution_networks = 2
    cost_scale_factor = 1e-6
    t_ref_extensions = [_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!]
    d_ref_extensions = [_FP.ref_add_gen!, _FP.ref_add_storage!, _FP.ref_add_ne_storage!, _FP.ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _FP.ref_add_ne_branch_allbranches!, _FP.ref_add_frb_branch!, _FP.ref_add_oltc_branch!]
    t_solution_processors = [_PM.sol_data_model!]
    d_solution_processors = [_PM.sol_data_model!, _FP.sol_td_coupling!]
    t_setting = Dict("conv_losses_mp" => false)
    d_setting = Dict{String,Any}()
    t_data = load_case6(; number_of_hours, number_of_scenarios=1, number_of_years=1, cost_scale_factor, share_data=false)
    d_data_sub = load_cigre_mv_eu(; flex_load=true, ne_storage=true, scale_gen=5.0, scale_wind=6.0, scale_load=1.0, number_of_hours, cost_scale_factor)
    d_data = Vector{Dict{String,Any}}(undef, number_of_distribution_networks)
    for s in 1:number_of_distribution_networks
        d_data[s] = deepcopy(d_data_sub)
        d_data[s]["t_bus"] = mod1(s, length(first(values(t_data["nw"]))["bus"])) # Attach distribution network to a transmission network bus
    end

    @testset "calc_surrogate_model" begin
        data = deepcopy(d_data[1])
        d_gen_id = _FP._get_reference_gen(data)
        _FP.add_dimension!(data, :sub_nw, Dict(1 => Dict{String,Any}("d_gen"=>d_gen_id)))
        sol_up, sol_base, sol_down = _FP.TDDecoupling.probe_distribution_flexibility!(data;
            model_type = _FP.BFA8PowerModel,
            optimizer = milp_optimizer,
            build_method = _FP.build_simple_stoch_flex_tnep,
            ref_extensions = d_ref_extensions,
            solution_processors = d_solution_processors
        )
        surrogate_distribution = _FP.TDDecoupling.calc_surrogate_model(d_data[1], sol_up, sol_base, sol_down)
        surr_nw_1 = surrogate_distribution["nw"]["1"]
        @test length(surr_nw_1["gen"])     == 1
        @test length(surr_nw_1["load"])    == 1
        @test length(surr_nw_1["storage"]) == 1
        for (n,nw) in surrogate_distribution["nw"]
            load = nw["load"]["1"]
            @test load["pd"]                  ≥ 0.0
            @test load["pshift_up_rel_max"]   ≥ 0.0
            @test load["pshift_down_rel_max"] ≥ 0.0
            @test load["pred_rel_max"]        ≥ 0.0
            storage = nw["storage"]["1"]
            @test storage["charge_rating"]             ≥ 0.0
            @test storage["discharge_rating"]          ≥ 0.0
            @test storage["stationary_energy_inflow"]  ≥ 0.0
            @test storage["stationary_energy_outflow"] ≥ 0.0
            @test storage["thermal_rating"]            ≥ 0.0
            gen = nw["gen"]["1"]
            @test gen["pmax"] ≥ 0.0
        end
    end

    @testset "run_td_decoupling" begin
        result = _FP.run_td_decoupling(
            t_data, d_data, _PM.DCPPowerModel, _FP.BFA8PowerModel, milp_optimizer, milp_optimizer, _FP.build_simple_stoch_flex_tnep;
            t_ref_extensions, d_ref_extensions, t_solution_processors, d_solution_processors, t_setting, d_setting
        )
        @test result["objective"] ≈ 2445.7 rtol=1e-3
        @test length(result["d_solution"]) == number_of_distribution_networks
        @test length(result["d_objective"]) == number_of_distribution_networks
    end

end;
