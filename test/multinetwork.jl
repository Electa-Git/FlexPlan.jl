@testset "Multinetwork dimensions" begin

    # Some tests here intentionally throw errors, so we temporarily raise the FlexPlan
    # logger level to prevent them from being displayed.
    previous_FlexPlan_logger_level = Memento.getlevel(Memento.getlogger(FlexPlan))
    Memento.setlevel!(Memento.getlogger(FlexPlan), "alert")

    benchmark = DataFrames.DataFrame(
        nw = 1:24,
        hour = repeat(1:4; outer=6),
        scenario = repeat(1:3; inner=4, outer=2),
        sub_nw = repeat(1:2; inner=12)
    )
    #=
    julia> display(benchmark)
    24×4 DataFrame
     Row │ nw     hour   scenario  sub_nw
         │ Int64  Int64  Int64     Int64
    ─────┼────────────────────────────────
       1 │     1      1         1       1
       2 │     2      2         1       1
       3 │     3      3         1       1
       4 │     4      4         1       1
       5 │     5      1         2       1
       6 │     6      2         2       1
       7 │     7      3         2       1
       8 │     8      4         2       1
       9 │     9      1         3       1
      10 │    10      2         3       1
      11 │    11      3         3       1
      12 │    12      4         3       1
      13 │    13      1         1       2
      14 │    14      2         1       2
      15 │    15      3         1       2
      16 │    16      4         1       2
      17 │    17      1         2       2
      18 │    18      2         2       2
      19 │    19      3         2       2
      20 │    20      4         2       2
      21 │    21      1         3       2
      22 │    22      2         3       2
      23 │    23      3         3       2
      24 │    24      4         3       2
    =#

    sn_data = Dict{String,Any}(c=>Dict{String,Any}() for c in ("bus","branch","dcline","gen","load","shunt","switch","storage")) # Fake a single-network data structure
    _FP.add_dimension!(sn_data, :hour, 4)
    _FP.add_dimension!(sn_data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/s) for s in 1:3))
    _FP.add_dimension!(sn_data, :sub_nw, 2; metadata = Dict{String,Any}("description"=>"sub_nws model different physical networks"))
    mn_data = Dict{String,Any}("dim"=>sn_data["dim"], "multinetwork"=>true, "nw"=>Dict{String,Any}("1"=>sn_data)) # Fake a multinetwork data structure
    pm = _PM.instantiate_model(mn_data, _PM.ACPPowerModel, pm->nothing)

    @testset "nw_ids()" begin
        @test _FP.nw_ids(pm)                         == benchmark.nw
        @test _FP.nw_ids(pm, hour=4)                 == DataFrames.filter(r -> r.hour==4, benchmark).nw
        @test _FP.nw_ids(pm, scenario=2)             == DataFrames.filter(r -> r.scenario==2, benchmark).nw
        @test _FP.nw_ids(pm, sub_nw=1)               == DataFrames.filter(r -> r.sub_nw==1, benchmark).nw
        @test _FP.nw_ids(pm, hour=4, scenario=2)     == DataFrames.filter(r -> r.hour==4 && r.scenario==2, benchmark).nw
        @test _FP.nw_ids(pm, hour=2:4)               == DataFrames.filter(r -> 2<=r.hour<=4, benchmark).nw
        @test _FP.nw_ids(pm, hour=2:4, scenario=2)   == DataFrames.filter(r -> 2<=r.hour<=4 && r.scenario==2, benchmark).nw
        @test _FP.nw_ids(pm, hour=[2,4])             == DataFrames.filter(r -> r.hour∈(2,4), benchmark).nw
        @test _FP.nw_ids(pm, hour=[2,4], scenario=2) == DataFrames.filter(r -> r.hour∈(2,4) && r.scenario==2, benchmark).nw
    end

    @testset "dim()" begin
        @test _FP.dim(pm, :hour) == Dict(h => Dict{String,Any}() for h in 1:4)
        @test _FP.dim(pm, :scenario) == Dict(s => Dict{String,Any}("probability"=>1/s) for s in 1:3)
    end

    @testset "dim_meta()" begin
        @test typeof(_FP.dim_meta(pm, :hour)) == Dict{String,Any}
        @test haskey(_FP.dim_meta(pm, :sub_nw), "description")
        @test _FP.dim_meta(pm, :sub_nw, "description") == "sub_nws model different physical networks"
    end

    @testset "is_first_nw()" begin
        @test _FP.is_first_nw(pm, 14, :hour) == false
        @test _FP.is_first_nw(pm, 14, :scenario) == true
        @test _FP.is_first_nw(pm, 17, :hour) == true
        @test _FP.is_first_nw(pm, 17, :scenario) == false
    end

    @testset "is_last_nw()" begin
        @test _FP.is_last_nw(pm, 20, :hour) == true
        @test _FP.is_last_nw(pm, 20, :scenario) == false
        @test _FP.is_last_nw(pm, 21, :hour) == false
        @test _FP.is_last_nw(pm, 21, :scenario) == true
    end

    @testset "first_nw()" begin
        @test _FP.first_nw(pm, 17, :hour) == 17
        @test _FP.first_nw(pm, 18, :hour) == 17
        @test _FP.first_nw(pm, 19, :hour) == 17
        @test _FP.first_nw(pm, 20, :hour) == 17
        @test _FP.first_nw(pm, 16, :scenario) == 16
        @test _FP.first_nw(pm, 19, :scenario) == 15
        @test _FP.first_nw(pm, 22, :scenario) == 14
        @test _FP.first_nw(pm, 13, :hour, :scenario) == 13
        @test _FP.first_nw(pm, 16, :hour, :scenario) == 13
        @test _FP.first_nw(pm, 21, :hour, :scenario) == 13
        @test _FP.first_nw(pm, 24, :hour, :scenario) == 13
    end

    @testset "last_nw()" begin
        @test _FP.last_nw(pm,  8, :hour) ==  8
        @test _FP.last_nw(pm,  7, :hour) ==  8
        @test _FP.last_nw(pm,  6, :hour) ==  8
        @test _FP.last_nw(pm,  5, :hour) ==  8
        @test _FP.last_nw(pm,  9, :scenario) ==  9
        @test _FP.last_nw(pm,  6, :scenario) == 10
        @test _FP.last_nw(pm,  3, :scenario) == 11
        @test _FP.last_nw(pm, 12, :hour, :scenario) == 12
        @test _FP.last_nw(pm,  9, :hour, :scenario) == 12
        @test _FP.last_nw(pm,  4, :hour, :scenario) == 12
        @test _FP.last_nw(pm,  1, :hour, :scenario) == 12
    end

    @testset "prev_nw()" begin
        @test_throws ErrorException _FP.prev_nw(pm, 17, :hour)
        @test _FP.prev_nw(pm, 18, :hour) == 17
        @test _FP.prev_nw(pm, 19, :hour) == 18
        @test _FP.prev_nw(pm, 20, :hour) == 19
        @test_throws ErrorException _FP.prev_nw(pm, 16, :scenario)
        @test _FP.prev_nw(pm, 19, :scenario) == 15
        @test _FP.prev_nw(pm, 22, :scenario) == 18
    end

    @testset "next_nw()" begin
        @test _FP.next_nw(pm, 5, :hour) ==  6
        @test _FP.next_nw(pm, 6, :hour) ==  7
        @test _FP.next_nw(pm, 7, :hour) ==  8
        @test_throws ErrorException _FP.next_nw(pm, 8, :hour)
        @test_throws ErrorException _FP.next_nw(pm, 9, :scenario)
        @test _FP.next_nw(pm, 6, :scenario) == 10
        @test _FP.next_nw(pm, 3, :scenario) ==  7
    end

    Memento.setlevel!(Memento.getlogger(FlexPlan), previous_FlexPlan_logger_level)

end;
