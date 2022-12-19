@testset "BFARadPowerModel" begin

    @testset "CIGRE TNEP single-period" begin
        data = _FP.parse_file(normpath(@__DIR__,"../test/data/cigre_mv_eu/cigre_mv_eu_unit_test.m"))
        _FP.add_dimension!(data, :hour, 1)
        _FP.add_dimension!(data, :year, 1)
        data = _FP.make_multinetwork(data)
        result = _FP.flex_tnep(data, _FP.BFARadPowerModel, milp_optimizer)
        sol = result["solution"]["nw"]["1"]
        @test result["termination_status"] == OPTIMAL
        @test result["objective"] ≈ 4360.45 rtol=1e-3
        @test sol["branch"]["16"]["pf"] ≈ -sol["branch"]["16"]["pt"] rtol=1e-3 # Zero active power losses in OLTC branch
        @test sol["branch"]["16"]["qf"] ≈ -sol["branch"]["16"]["qt"] rtol=1e-3 # Zero reactive power losses in OLTC branch
        @test sol["branch"]["17"]["pf"] ≈ -sol["branch"]["17"]["pt"] rtol=1e-3 # Zero active power losses in frb branch
        @test sol["branch"]["17"]["qf"] ≈ -sol["branch"]["17"]["qt"] rtol=1e-3 # Zero reactive power losses in frb branch
        @test sol["branch"]["1"]["pf"] ≈ -sol["branch"]["1"]["pt"] rtol=1e-3 # Zero active power losses in regular branch
        @test sol["branch"]["1"]["qf"] ≈ -sol["branch"]["1"]["qt"] rtol=1e-3 # Zero reactive power losses in regular branch
        @test sol["ne_branch"]["1"]["built"] ≈ 0.0 atol=1e-1 # Unused OLTC ne_branch
        @test sol["ne_branch"]["2"]["built"] ≈ 0.0 atol=1e-1 # Unused frb ne_branch
        @test sol["ne_branch"]["3"]["built"] ≈ 0.0 atol=1e-1 # Unused regular ne_branch
        @test sol["ne_branch"]["1"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in unused OLTC ne_branch
        @test sol["ne_branch"]["1"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in unused OLTC ne_branch
        @test sol["ne_branch"]["2"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in unused frb ne_branch
        @test sol["ne_branch"]["2"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in unused frb ne_branch
        @test sol["ne_branch"]["3"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in unused regular ne_branch
        @test sol["ne_branch"]["3"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in unused regular ne_branch
        @test sum(g["pg"] for g in values(sol["gen"])) ≈ sum(l["pflex"] for l in values(sol["load"])) rtol=1e-3 # Zero overall active power losses
        @test sum(g["qg"] for g in values(sol["gen"])) ≈ sum(l["qflex"] for l in values(sol["load"])) rtol=1e-3 # Zero overall reactive power losses

        data["nw"]["1"]["load"]["1"]["pd"] += 10.0 # Bus 1. Changes reactive power demand too, via `pf_angle`.
        data["nw"]["1"]["load"]["12"]["pd"] += 4.0 # Bus 13. Changes reactive power demand too, via `pf_angle`.
        data["nw"]["1"]["branch"]["12"]["rate_a"] = data["nw"]["1"]["branch"]["12"]["rate_b"] = data["nw"]["1"]["branch"]["12"]["rate_c"] = 0.0
        result = _FP.flex_tnep(data, _FP.BFARadPowerModel, milp_optimizer)
        sol = result["solution"]["nw"]["1"]
        @test result["termination_status"] == OPTIMAL
        @test result["objective"] ≈ 5764.48 rtol=1e-3
        @test sol["ne_branch"]["1"]["built"] ≈ 1.0 atol=1e-1 # Replacement OLTC ne_branch
        @test sol["ne_branch"]["2"]["built"] ≈ 1.0 atol=1e-1 # frb ne_branch added in parallel
        @test sol["ne_branch"]["3"]["built"] ≈ 1.0 atol=1e-1 # Replacement regular ne_branch
        @test sol["ne_branch"]["4"]["built"] ≈ 0.0 atol=1e-1 # Unused ne_branch
        @test sol["ne_branch"]["1"]["pf"] ≈ -sol["ne_branch"]["1"]["pt"] rtol=1e-3 # Zero active power losses in OLTC ne_branch
        @test sol["ne_branch"]["1"]["qf"] ≈ -sol["ne_branch"]["1"]["qt"] rtol=1e-3 # Zero reactive power losses in OLTC ne_branch
        @test sol["ne_branch"]["2"]["pf"] ≈ -sol["ne_branch"]["2"]["pt"] rtol=1e-3 # Zero active power losses in frb ne_branch
        @test sol["ne_branch"]["2"]["qf"] ≈ -sol["ne_branch"]["2"]["qt"] rtol=1e-3 # Zero reactive power losses in frb ne_branch
        @test sol["ne_branch"]["3"]["pf"] ≈ -sol["ne_branch"]["3"]["pt"] rtol=1e-3 # Zero active power losses in regular ne_branch
        @test sol["ne_branch"]["3"]["qf"] ≈ -sol["ne_branch"]["3"]["qt"] rtol=1e-3 # Zero reactive power losses in regular ne_branch
        @test sol["branch"]["16"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in replaced OLTC branch
        @test sol["branch"]["16"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in replaced OLTC branch
        @test sol["branch"]["17"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in replaced frb branch
        @test sol["branch"]["17"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in replaced frb branch
        @test sol["branch"]["13"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in replaced regular branch
        @test sol["branch"]["13"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in replaced regular branch
        @test sol["branch"]["12"]["pf"] ≈ 0.0 atol=1e-2 # Zero active power in branch having zero rating
        @test sol["branch"]["12"]["qf"] ≈ 0.0 atol=1e-2 # Zero reactive power in branch having zero rating
    end

end;
