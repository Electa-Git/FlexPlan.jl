# Test flexible load model using a multiperiod optimization

# - Model: `_FP.BFARadPowerModel` is used to be able to test loads in both active and
#   reactive power, while keeping the model linear. It requires a distribution network.
# - Problem: `flex_tnep` is the simplest problem that implement flexible loads.

## Settings

file = normpath(@__DIR__,"..","test","data","case2_d_flex.m") # Input case. Here 2-bus distribution network having 1 generator and 1 load, both on bus 1 (bus 2 is empty).
number_of_hours = 24 # Number of time periods

## Plot function

# Uncomment this part and the commented lines further down to see a nice plot when manually editing a testset
#=
using StatsPlots
function plot_flex_load(mn_data, result)
    res_load(i,key) = [result["solution"]["nw"]["$n"]["load"]["$i"][key] for n in 1:number_of_hours]
    data_load(i,key) = [mn_data["nw"]["$n"]["load"]["$i"][key] for n in 1:number_of_hours]
    load_matrix = hcat(res_load.(1,["pshift_up" "pshift_down" "pnce" "pcurt" "pflex"])...) # Rows: hours; columns: power categories
    load_matrix[:,5] -= load_matrix[:,1] # min(pd,pflex) == pflex-pshift_up
    plt = groupedbar(load_matrix;
        yguide = "Power [p.u.]",
        xguide = "Time [h]",
        bar_position = :stack,
        bar_width = 1,
        linecolor = HSLA(0,0,1,0),
        legend_position = :topleft,
        label = ["pshift_up" "pshift_down" "pnce" "pcurt" :none],
        seriescolor = [HSLA(210,1,0.5,0.5) HSLA(0,0.75,0.75,0.5) HSLA(0,0.5,0.5,0.5) HSLA(0,0.75,0.25,0.5) HSLA(0,0,0,0.1)],
    )
    plot!(plt, data_load(1,"pd"); label="pd", seriestype=:stepmid, linecolor=:black, linewidth=2, linestyle=:dot)
    plot!(plt, res_load(1,"pflex"); label="pflex", seriestype=:stepmid, linecolor=:black)
    display(plt)
end
=#


## Test results

@testset "Load model" begin

    # Case where there is a flexible load and it is activated. As demand exceeds by far
    # available generation in the second half of the time horizon, demand shifting and
    # voluntary reduction are exploited to their maximum extent. Involuntary curtailment
    # covers the remaining excess of demand.
    @testset "Flex load - active" begin
        data = _FP.parse_file(file)
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
        _FP.scale_data!(data; cost_scale_factor=1e-6)
        loadprofile = collect(range(0,2,number_of_hours))' # Create a load profile: ramp from 0 to 2 times the rated value of load
        time_series = _FP.create_profile_data(number_of_hours, data, loadprofile) # Compute time series by multiplying the rated value by the profile
        mn_data = _FP.make_multinetwork(data, time_series)
        result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)
        #plot_flex_load(mn_data, result)

        @test result["solution"]["nw"][ "1"]["load"]["1"]["isflex"]          ≈   1.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_up_tot"]   ≈   6.957   rtol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_down_tot"] ≈   6.957   rtol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["ence"]            ≈  12.0     rtol=1e-3
        for n in 1 : number_of_hours÷2
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_down"] ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pnce"]        ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pcurt"]       ≈   0.0     atol=1e-3
        end
        for n in number_of_hours÷2+1 : number_of_hours
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_up"]   ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pflex"]       ≈  10.0     rtol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["qflex"]       ≈   2.0     rtol=1e-3
        end
        @test result["objective"]                                            ≈ 163.2     rtol=1e-3
    end

    # Case where there is a flexible load but it is not activated. Demand exceeds available
    # generation in the second half of the time horizon; involuntary curtailment is the only
    # option to decrease the demand.
    @testset "Flex load - not active" begin
        data = _FP.parse_file(file)
        data["load"]["1"]["cost_investment"] = 1e10 # Increase the cost of flexibility-enabling equipment so that flexibility is not enabled in optimal solution
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
        _FP.scale_data!(data; cost_scale_factor=1e-6)
        loadprofile = collect(range(0,2,number_of_hours))' # Create a load profile: ramp from 0 to 2 times the rated value of load
        time_series = _FP.create_profile_data(number_of_hours, data, loadprofile) # Compute time series by multiplying the rated value by the profile
        mn_data = _FP.make_multinetwork(data, time_series)
        result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)
        #plot_flex_load(mn_data, result)

        @test result["solution"]["nw"][ "1"]["load"]["1"]["isflex"]          ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_up_tot"]   ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_down_tot"] ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["ence"]            ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pcurt"]           ≈  10.0     rtol=1e-3
        for n in 1 : number_of_hours
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_up"]   ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_down"] ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pnce"]        ≈   0.0     atol=1e-3
        end
        for n in 1 : number_of_hours÷2
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pcurt"]       ≈   0.0     atol=1e-3
        end
        for n in number_of_hours÷2+1 : number_of_hours
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pflex"]       ≈  10.0     rtol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["qflex"]       ≈   2.0     rtol=1e-3
        end
        @test result["objective"]                                            ≈ 231.8     rtol=1e-3
    end

    # Case where there is a fixed load. Demand exceeds available generation in the second
    # half of the time horizon; involuntary curtailment is the only option to decrease the
    # demand.
    @testset "Fixed load" begin
        data = _FP.parse_file(file)
        data["load"]["1"]["flex"] = 0 # State that the load cannot be made flexible
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
        _FP.scale_data!(data; cost_scale_factor=1e-6)
        loadprofile = collect(range(0,2,number_of_hours))' # Create a load profile: ramp from 0 to 2 times the rated value of load
        time_series = _FP.create_profile_data(number_of_hours, data, loadprofile) # Compute time series by multiplying the rated value by the profile
        mn_data = _FP.make_multinetwork(data, time_series)
        result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)
        #plot_flex_load(mn_data, result)

        @test result["solution"]["nw"][ "1"]["load"]["1"]["isflex"]          ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_up_tot"]   ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pshift_down_tot"] ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["ence"]            ≈   0.0     atol=1e-3
        @test result["solution"]["nw"]["24"]["load"]["1"]["pcurt"]           ≈  10.0     rtol=1e-3
        for n in 1 : number_of_hours
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_up"]   ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pshift_down"] ≈   0.0     atol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pnce"]        ≈   0.0     atol=1e-3
        end
        for n in 1 : number_of_hours÷2
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pcurt"]       ≈   0.0     atol=1e-3
        end
        for n in number_of_hours÷2+1 : number_of_hours
            @test result["solution"]["nw"]["$n"]["load"]["1"]["pflex"]       ≈  10.0     rtol=1e-3
            @test result["solution"]["nw"]["$n"]["load"]["1"]["qflex"]       ≈   2.0     rtol=1e-3
        end
        @test result["objective"]                                            ≈ 231.8     rtol=1e-3
    end

end;
