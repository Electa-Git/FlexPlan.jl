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
    _FP.add_dimension!(sn_data, :scenario, Dict(s => Dict{String,Any}("probability"=>1/3) for s in 1:3))
    _FP.add_dimension!(sn_data, :sub_nw, 2; metadata = Dict{String,Any}("description"=>"sub_nws model different physical networks"))
    dt = Dict{String,Any}("dim"=>sn_data["dim"], "multinetwork"=>true, "nw"=>Dict{String,Any}("1"=>sn_data)) # Fake a multinetwork data structure
    pm = _PM.instantiate_model(dt, _PM.ACPPowerModel, pm->nothing)

    @testset "add_dimension!" begin
        @test_throws ErrorException _FP.add_dimension!(sn_data, :hour, 4) # Trying to add a dimension having the same name of an existing one
        @test_throws ErrorException _FP.add_dimension!(sn_data, :newdim, Dict(s => Dict{String,Any}("prop"=>"val") for s in [1,2,4])) # Trying to add a dimension having a property Dict whose keys are not consecutive Ints starting at 1
    end

    @testset "nw_ids" begin
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

    @testset "similar_ids" begin
        @test _FP.similar_ids(pm, 7)                           == [7]
        @test _FP.similar_ids(pm, 7, hour=4)                   == [8]
        @test _FP.similar_ids(pm, 7, scenario=1)               == [3]
        @test _FP.similar_ids(pm, 7, hour=4, scenario=1)       == [4]
        @test _FP.similar_ids(pm, 7, hour=2:4)                 == [6,7,8]
        @test _FP.similar_ids(pm, 7, hour=[2,4])               == [6,8]
        @test _FP.similar_ids(pm, 7, scenario=1:3)             == [3,7,11]
        @test _FP.similar_ids(pm, 7, scenario=[1,3])           == [3,11]
        @test _FP.similar_ids(pm, 7, hour=[2,4], scenario=1:3) == [2,4,6,8,10,12]
    end

    @testset "similar_id" begin
        @test _FP.similar_id(pm, 7)                     == 7
        @test _FP.similar_id(pm, 7, hour=4)             == 8
        @test _FP.similar_id(pm, 7, scenario=1)         == 3
        @test _FP.similar_id(pm, 7, hour=4, scenario=1) == 4
    end

    @testset "first_nw" begin
        @test _FP.first_id(pm, 17, :hour) == 17
        @test _FP.first_id(pm, 18, :hour) == 17
        @test _FP.first_id(pm, 19, :hour) == 17
        @test _FP.first_id(pm, 20, :hour) == 17
        @test _FP.first_id(pm, 16, :scenario) == 16
        @test _FP.first_id(pm, 19, :scenario) == 15
        @test _FP.first_id(pm, 22, :scenario) == 14
        @test _FP.first_id(pm, 13, :hour, :scenario) == 13
        @test _FP.first_id(pm, 16, :hour, :scenario) == 13
        @test _FP.first_id(pm, 21, :hour, :scenario) == 13
        @test _FP.first_id(pm, 24, :hour, :scenario) == 13
    end

    @testset "last_nw" begin
        @test _FP.last_id(pm,  8, :hour) ==  8
        @test _FP.last_id(pm,  7, :hour) ==  8
        @test _FP.last_id(pm,  6, :hour) ==  8
        @test _FP.last_id(pm,  5, :hour) ==  8
        @test _FP.last_id(pm,  9, :scenario) ==  9
        @test _FP.last_id(pm,  6, :scenario) == 10
        @test _FP.last_id(pm,  3, :scenario) == 11
        @test _FP.last_id(pm, 12, :hour, :scenario) == 12
        @test _FP.last_id(pm,  9, :hour, :scenario) == 12
        @test _FP.last_id(pm,  4, :hour, :scenario) == 12
        @test _FP.last_id(pm,  1, :hour, :scenario) == 12
    end

    @testset "prev_nw" begin
        @test_throws BoundsError _FP.prev_id(pm, 17, :hour)
        @test _FP.prev_id(pm, 18, :hour) == 17
        @test _FP.prev_id(pm, 19, :hour) == 18
        @test _FP.prev_id(pm, 20, :hour) == 19
        @test_throws BoundsError _FP.prev_id(pm, 16, :scenario)
        @test _FP.prev_id(pm, 19, :scenario) == 15
        @test _FP.prev_id(pm, 22, :scenario) == 18
    end

    @testset "prev_nws" begin
        @test _FP.prev_ids(pm, 17, :hour) == []
        @test _FP.prev_ids(pm, 18, :hour) == [17]
        @test _FP.prev_ids(pm, 20, :hour) == [17,18,19]
        @test _FP.prev_ids(pm, 16, :scenario) == []
        @test _FP.prev_ids(pm, 19, :scenario) == [15]
        @test _FP.prev_ids(pm, 22, :scenario) == [14,18]
    end

    @testset "next_nw" begin
        @test _FP.next_id(pm, 5, :hour) ==  6
        @test _FP.next_id(pm, 6, :hour) ==  7
        @test _FP.next_id(pm, 7, :hour) ==  8
        @test_throws BoundsError _FP.next_id(pm, 8, :hour)
        @test_throws BoundsError _FP.next_id(pm, 9, :scenario)
        @test _FP.next_id(pm, 6, :scenario) == 10
        @test _FP.next_id(pm, 3, :scenario) ==  7
    end

    @testset "next_nws" begin
        @test _FP.next_ids(pm, 5, :hour) == [6,7,8]
        @test _FP.next_ids(pm, 7, :hour) == [8]
        @test _FP.next_ids(pm, 8, :hour) == []
        @test _FP.next_ids(pm, 9, :scenario) == []
        @test _FP.next_ids(pm, 6, :scenario) == [10]
        @test _FP.next_ids(pm, 3, :scenario) == [7,11]
    end

    @testset "is_first_nw" begin
        @test _FP.is_first_id(pm, 14, :hour) == false
        @test _FP.is_first_id(pm, 14, :scenario) == true
        @test _FP.is_first_id(pm, 17, :hour) == true
        @test _FP.is_first_id(pm, 17, :scenario) == false
    end

    @testset "is_last_nw" begin
        @test _FP.is_last_id(pm, 20, :hour) == true
        @test _FP.is_last_id(pm, 20, :scenario) == false
        @test _FP.is_last_id(pm, 21, :hour) == false
        @test _FP.is_last_id(pm, 21, :scenario) == true
    end

    @testset "dim_prop" begin
        @test Set(keys(_FP.dim_prop(dt))) == Set((:hour, :scenario, :sub_nw))
        @test Set(keys(_FP.dim_prop(pm))) == Set((:hour, :scenario, :sub_nw))
        @test _FP.dim_prop(dt, :hour) == Dict(h => Dict{String,Any}() for h in 1:4)
        @test _FP.dim_prop(pm, :hour) == Dict(h => Dict{String,Any}() for h in 1:4)
        @test _FP.dim_prop(dt, :scenario) == Dict(s => Dict{String,Any}("probability"=>1/3) for s in 1:3)
        @test _FP.dim_prop(pm, :scenario) == Dict(s => Dict{String,Any}("probability"=>1/3) for s in 1:3)
        @test _FP.dim_prop(dt, :scenario, 1) == Dict{String,Any}("probability"=>1/3)
        @test _FP.dim_prop(pm, :scenario, 1) == Dict{String,Any}("probability"=>1/3)
        @test _FP.dim_prop(dt, :scenario, 1, "probability") == 1/3
        @test _FP.dim_prop(pm, :scenario, 1, "probability") == 1/3
    end

    @testset "dim_meta" begin
        @test Set(keys(_FP.dim_meta(dt))) == Set((:hour, :scenario, :sub_nw))
        @test Set(keys(_FP.dim_meta(pm))) == Set((:hour, :scenario, :sub_nw))
        @test _FP.dim_meta(dt, :hour) == Dict{String,Any}()
        @test _FP.dim_meta(pm, :hour) == Dict{String,Any}()
        @test _FP.dim_meta(dt, :sub_nw) == Dict{String,Any}("description" => "sub_nws model different physical networks")
        @test _FP.dim_meta(pm, :sub_nw) == Dict{String,Any}("description" => "sub_nws model different physical networks")
        @test _FP.dim_meta(dt, :sub_nw, "description") == "sub_nws model different physical networks"
        @test _FP.dim_meta(pm, :sub_nw, "description") == "sub_nws model different physical networks"
    end

    @testset "dim_length" begin
        @test _FP.dim_length(dt, :hour) == 4
        @test _FP.dim_length(pm, :hour) == 4
        @test _FP.dim_length(dt, :scenario) == 3
        @test _FP.dim_length(pm, :scenario) == 3
    end

    Memento.setlevel!(Memento.getlogger(FlexPlan), previous_FlexPlan_logger_level)

end;
