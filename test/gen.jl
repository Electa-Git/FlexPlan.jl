# Test generator models using a multiperiod optimization

# - Model: `_FP.BFARadPowerModel` is used to be able to test generators in both active and
#   reactive power, while keeping the model linear. It requires a distribution network.
# - Problem: `flex_tnep`.

## Settings

file = normpath(@__DIR__,"..","test","data","case2","case2_d_gen.m") # Input case. Here 2-bus distribution network having 1 dispatchable generator, 1 non-dispatchable generator and 1 fixed load, all on bus 1 (bus 2 is empty).
number_of_hours = 5 # Number of time periods

## Plot function

# Uncomment this part and the commented lines further down to display some nice plots when manually editing a testset
#=
using StatsPlots
function plot_bus(mn_data, result)
    res_gen(i,key) = [result["solution"]["nw"]["$n"]["gen"]["$i"][key] for n in 1:number_of_hours]
    data_gen(i,key) = [mn_data["nw"]["$n"]["gen"]["$i"][key] for n in 1:number_of_hours]
    data_load(i,key) = [mn_data["nw"]["$n"]["load"]["$i"][key] for n in 1:number_of_hours]
    gen_matrix = hcat(res_gen(1,"pgcurt"), res_gen(2,"pgcurt"), res_gen(1,"pg"), res_gen(2,"pg")) # Rows: hours; columns: power categories
    plt = groupedbar(gen_matrix;
        title = "Bus 1",
        yguide = "Power [p.u.]",
        xguide = "Time [h]",
        framestyle = :zerolines,
        bar_position = :stack,
        bar_width = 1,
        linecolor = HSLA(0,0,1,0),
        legend_position = :topleft,
        label = ["gen1 pgcurt" "gen2 pgcurt" "gen1 pg" "gen2 pg"],
        seriescolor = [HSLA(0,0.5,0.5,0.5) HSLA(0,0.75,0.25,0.5) HSLA(210,0.75,0.5,0.5) HSLA(210,1,0.25,0.5)],
    )
    plot!(plt, data_load(1,"pd"); label="demand", seriestype=:stepmid, linecolor=:black, linewidth=2, linestyle=:dot)
    display(plt)
end
function plot_gen(mn_data, result, i)
    res_gen(i,key) = [result["solution"]["nw"]["$n"]["gen"]["$i"][key] for n in 1:number_of_hours]
    data_gen(i,key) = [mn_data["nw"]["$n"]["gen"]["$i"][key] for n in 1:number_of_hours]
    gen_matrix = hcat(res_gen.(i,["pgcurt" "pg"])...) # Rows: hours; columns: power categories
    plt = groupedbar(gen_matrix;
        title = "Generator $i",
        yguide = "Power [p.u.]",
        xguide = "Time [h]",
        framestyle = :zerolines,
        bar_position = :stack,
        bar_width = 1,
        linecolor = HSLA(0,0,1,0),
        legend_position = :topleft,
        label = ["pgcurt" "pg"],
        seriescolor = [HSLA(0,0.75,0.25,0.5) HSLA(210,0.75,0.5,0.5)],
    )
    plot!(plt, data_gen(i,"pmax"); label="pmax", seriestype=:stepmid, linecolor=:black, linewidth=2, linestyle=:dot)
    plot!(plt, data_gen(i,"pmin"); label="pmin", seriestype=:stepmid, linecolor=:black, linewidth=1, linestyle=:dash)
    display(plt)
end
=#


## Test results

@testset "Generator model" begin

    # The power required by a fixed load linearly increases from 0 to 20 MW. Generator 2 is
    # non-dispatchable and its reference power decreases from 20 MW to 0 MW, so it is
    # curtailed in the first half of the time horizon and used at full power in the second
    # half. Generator 1, which is dispatchable and can range from 0 to 15 MW, covers the
    # rest of the demand in subsequent periods, until reaches its maximum power; after that,
    # the load is curtailed.
    data = _FP.parse_file(file)
    _FP.add_dimension!(data, :hour, number_of_hours)
    _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
    _FP.scale_data!(data; cost_scale_factor=1e-6)
    loadprofile = collect(reshape(range(0,2;length=number_of_hours),:,1)) # Create a load profile: ramp from 0 to 2 times the rated value of load
    genprofile = hcat(1.5.*ones(number_of_hours), reverse(loadprofile; dims=1)) # Generator 1: 2 times the rated value; generator 2: ramp from 2 times the rated value to 0
    time_series = _FP.make_time_series(data; loadprofile, genprofile) # Compute time series by multiplying the rated value by the profile
    mn_data = _FP.make_multinetwork(data, time_series)
    result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)
    #plot_bus(mn_data, result)

    @testset "Dispatchable generator" begin
        #plot_gen(mn_data, result, 1)
        @test result["solution"]["nw"]["1"]["gen"]["1"]["pg"]     ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["2"]["gen"]["1"]["pg"]     ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["3"]["gen"]["1"]["pg"]     ≈  0.0 atol=1e-3 # Here demand is covered by generator 2, which is non-dispatchable
        @test result["solution"]["nw"]["4"]["gen"]["1"]["pg"]     ≈ 10.0 rtol=1e-3
        @test result["solution"]["nw"]["5"]["gen"]["1"]["pg"]     ≈ 15.0 rtol=1e-3 # Must not exceed `pmax` even if the load requires more power
        @test result["solution"]["nw"]["1"]["gen"]["1"]["pgcurt"] ≈  0.0 atol=1e-3 # Dispatchable generators are not curtailable: `pgcurt` is always zero
        @test result["solution"]["nw"]["2"]["gen"]["1"]["pgcurt"] ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["3"]["gen"]["1"]["pgcurt"] ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["4"]["gen"]["1"]["pgcurt"] ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["5"]["gen"]["1"]["pgcurt"] ≈  0.0 atol=1e-3
    end

    @testset "Non-dispatchable generator" begin
        #plot_gen(mn_data, result, 2)
        @test result["solution"]["nw"]["1"]["gen"]["2"]["pg"]     ≈  0.0 atol=1e-3 # Curtailment is the only way to decrease generated power; here is completely exploited
        @test result["solution"]["nw"]["2"]["gen"]["2"]["pg"]     ≈  5.0 rtol=1e-3
        @test result["solution"]["nw"]["3"]["gen"]["2"]["pg"]     ≈ 10.0 rtol=1e-3
        @test result["solution"]["nw"]["4"]["gen"]["2"]["pg"]     ≈  5.0 rtol=1e-3 # Must not exceed `pmax`; the rest of the demand is covered by generator 1
        @test result["solution"]["nw"]["5"]["gen"]["2"]["pg"]     ≈  0.0 atol=1e-3 # Must not exceed `pmax` even if the load requires more power
        @test result["solution"]["nw"]["1"]["gen"]["2"]["pgcurt"] ≈ 20.0 rtol=1e-3 # Curtailment is the only way to decrease generated power; here is completely exploited
        @test result["solution"]["nw"]["2"]["gen"]["2"]["pgcurt"] ≈ 10.0 rtol=1e-3
        @test result["solution"]["nw"]["3"]["gen"]["2"]["pgcurt"] ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["4"]["gen"]["2"]["pgcurt"] ≈  0.0 atol=1e-3
        @test result["solution"]["nw"]["5"]["gen"]["2"]["pgcurt"] ≈  0.0 atol=1e-3
    end

end;
