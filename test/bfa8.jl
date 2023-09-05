@testset "BFA8PowerModel" begin

    @testset "CIGRE TNEP single-period" begin
        original_data = _FP.parse_file(normpath(@__DIR__,"../test/data/cigre_mv_eu/cigre_mv_eu_unit_test.m"))
        _FP.add_dimension!(original_data, :hour, 1)
        _FP.add_dimension!(original_data, :year, 1)
        original_data = _FP.make_multinetwork(original_data)

        data = deepcopy(original_data)
        result = _FP.flex_tnep(data, _FP.BFA8PowerModel, milp_optimizer)
        sol = result["solution"]["nw"]["1"]
        @test result["termination_status"] == OPTIMAL
        @test result["objective"] ≈ 4367.98 rtol=1e-3
        @test sol["branch"]["16"]["pf"] ≈ -sol["branch"]["16"]["pt"] rtol=1e-3 # Zero active power losses in OLTC branch
        @test sol["branch"]["16"]["qf"] ≈ -sol["branch"]["16"]["qt"] rtol=1e-3 # Zero reactive power losses in OLTC branch
        @test sol["branch"]["17"]["pf"] ≈ -sol["branch"]["17"]["pt"] rtol=1e-3 # Zero active power losses in frb branch
        @test sol["branch"]["17"]["qf"] ≈ -sol["branch"]["17"]["qt"] rtol=1e-3 # Zero reactive power losses in frb branch
        @test sol["branch"]["1"]["pf"] ≈ -sol["branch"]["1"]["pt"] rtol=1e-3 # Zero active power losses in regular branch
        @test sol["branch"]["1"]["qf"] ≈ -sol["branch"]["1"]["qt"] rtol=1e-3 # Zero reactive power losses in regular branch
        @test sol["ne_branch"]["1"]["built"] ≈ 0.0 atol=1e-3 # Unused OLTC ne_branch
        @test sol["ne_branch"]["2"]["built"] ≈ 0.0 atol=1e-3 # Unused frb ne_branch
        @test sol["ne_branch"]["3"]["built"] ≈ 0.0 atol=1e-3 # Unused regular ne_branch
        @test sol["ne_branch"]["1"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in unused OLTC ne_branch
        @test sol["ne_branch"]["1"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in unused OLTC ne_branch
        @test sol["ne_branch"]["2"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in unused frb ne_branch
        @test sol["ne_branch"]["2"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in unused frb ne_branch
        @test sol["ne_branch"]["3"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in unused regular ne_branch
        @test sol["ne_branch"]["3"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in unused regular ne_branch
        @test sol["convdc_ne"]["1"]["isbuilt"] ≈ 0.0 atol=1e-3 # Unused candidate converter
        @test sol["convdc_ne"]["1"]["pgrid"] ≈ 0.0 atol=1e-3 # Zero active power in AC side of unused candidate converter
        @test sol["convdc_ne"]["1"]["qgrid"] ≈ 0.0 atol=1e-3 # Zero reactive power in AC side of unused candidate converter
        @test sol["convdc_ne"]["1"]["pdc"] ≈ 0.0 atol=1e-3 # Zero power in DC side of unused candidate converter
        @test sol["branchdc"]["1"]["pf"] ≈ -sol["branchdc"]["1"]["pt"] rtol=1e-3 # Zero power losses in DC branch
        @test sol["branchdc_ne"]["1"]["isbuilt"] ≈ 0.0 atol=1e-3 # Unused candidate DC branch
        @test sol["branchdc_ne"]["1"]["pf"] ≈ 0.0 atol=1e-3 # Zero power at from side of unused candidate DC branch
        @test sol["branchdc_ne"]["1"]["pt"] ≈ 0.0 atol=1e-3 # Zero power at to side of unused candidate DC branch
        @test sum(g["pg"] for g in values(sol["gen"])) - sum(l["pflex"] for l in values(sol["load"])) ≈ sum(c["pgrid"] for c in values(sol["convdc"])) + sum(c["pgrid"] for c in values(sol["convdc_ne"])) rtol=1e-3 # Losses are due to converters
        @test sum(g["qg"] for g in values(sol["gen"])) - sum(l["qflex"] for l in values(sol["load"])) ≈ sum(c["qgrid"] for c in values(sol["convdc"])) + sum(c["qgrid"] for c in values(sol["convdc_ne"])) rtol=1e-3 # Losses are due to converters

        # Case: increase demand and force a zero rating on a branch
        data = deepcopy(original_data)
        data["nw"]["1"]["load"]["1"]["pd"] += 10.0 # Bus 1. Changes reactive power demand too, via `pf_angle`.
        data["nw"]["1"]["load"]["12"]["pd"] += 4.0 # Bus 13. Changes reactive power demand too, via `pf_angle`.
        data["nw"]["1"]["branch"]["12"]["rate_a"] = 0.0
        result = _FP.flex_tnep(data, _FP.BFA8PowerModel, milp_optimizer)
        sol = result["solution"]["nw"]["1"]
        @test result["termination_status"] == OPTIMAL
        @test result["objective"] ≈ 5772.01 rtol=1e-3
        @test sol["ne_branch"]["1"]["built"] ≈ 1.0 atol=1e-3 # Replacement OLTC ne_branch
        @test sol["ne_branch"]["2"]["built"] ≈ 1.0 atol=1e-3 # frb ne_branch added in parallel
        @test sol["ne_branch"]["3"]["built"] ≈ 1.0 atol=1e-3 # Replacement regular ne_branch
        @test sol["ne_branch"]["4"]["built"] ≈ 0.0 atol=1e-3 # Unused ne_branch
        @test sol["ne_branch"]["1"]["pf"] ≈ -sol["ne_branch"]["1"]["pt"] rtol=1e-3 # Zero active power losses in OLTC ne_branch
        @test sol["ne_branch"]["1"]["qf"] ≈ -sol["ne_branch"]["1"]["qt"] rtol=1e-3 # Zero reactive power losses in OLTC ne_branch
        @test sol["ne_branch"]["2"]["pf"] ≈ -sol["ne_branch"]["2"]["pt"] rtol=1e-3 # Zero active power losses in frb ne_branch
        @test sol["ne_branch"]["2"]["qf"] ≈ -sol["ne_branch"]["2"]["qt"] rtol=1e-3 # Zero reactive power losses in frb ne_branch
        @test sol["ne_branch"]["3"]["pf"] ≈ -sol["ne_branch"]["3"]["pt"] rtol=1e-3 # Zero active power losses in regular ne_branch
        @test sol["ne_branch"]["3"]["qf"] ≈ -sol["ne_branch"]["3"]["qt"] rtol=1e-3 # Zero reactive power losses in regular ne_branch
        @test sol["branch"]["16"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in replaced OLTC branch
        @test sol["branch"]["16"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in replaced OLTC branch
        @test sol["branch"]["17"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in replaced frb branch
        @test sol["branch"]["17"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in replaced frb branch
        @test sol["branch"]["13"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in replaced regular branch
        @test sol["branch"]["13"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in replaced regular branch
        @test sol["branch"]["12"]["pf"] ≈ 0.0 atol=1e-3 # Zero active power in branch having zero rating
        @test sol["branch"]["12"]["qf"] ≈ 0.0 atol=1e-3 # Zero reactive power in branch having zero rating

        # Case: remove the HV-MV substation at bus 12, so that power is provided by DC connection from bus 1
        data = deepcopy(original_data)
        data["nw"]["1"]["branch"]["17"]["br_status"] = 0 # Existing transformer feeding bus 12
        data["nw"]["1"]["ne_branch"]["2"]["br_status"] = 0 # Candidate transformer feeding bus 12
        data["nw"]["1"]["load"]["11"]["pd"] = 25 # Bus 12
        result = _FP.flex_tnep(data, _FP.BFA8PowerModel, milp_optimizer)
        sol = result["solution"]["nw"]["1"]
        @test result["termination_status"] == OPTIMAL
        @test result["objective"] ≈ 4921.72 rtol=1e-3
        @test sol["convdc_ne"]["1"]["isbuilt"] ≈ 1.0 atol=1e-3 # Used candidate converter
        @test sol["branchdc_ne"]["1"]["isbuilt"] ≈ 1.0 atol=1e-3 # Used candidate DC branch
        @test sol["branchdc_ne"]["1"]["pf"] ≈ -sol["branchdc_ne"]["1"]["pt"] rtol=1e-3 # Zero power losses in used candidate DC branch
    end

end;
