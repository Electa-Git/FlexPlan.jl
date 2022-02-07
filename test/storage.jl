# Test storage model using a multiperiod optimization

# - Model: `_FP.BFARadPowerModel` is used to be able to test storage in both active and
#   reactive power, while keeping the model linear. It requires a distribution network.
# - Problem: `flex_tnep` is the simplest problem that implements both storage and flexible
#   loads.

## Settings

file = normpath(@__DIR__,"..","test","data","case2_d_strg.m") # Input case. Here 2-bus distribution network having 1 generator, 1 load, 1 storage, and 1 candidate storage, all on bus 1 (bus 2 is empty).
number_of_hours = 4 # Number of time periods

## Plot function

# Uncomment this part and the commented lines further down to display a nice plot when manually editing a testset
#=
using StatsPlots
function plot_storage(mn_data, result; candidate::Bool, id::Int=1)
    id = string(id)
    storage_type = candidate ? "ne_storage" : "storage"
    res_storage(key) = [result["solution"]["nw"]["$n"][storage_type][id][key] for n in 1:number_of_hours]
    data_storage(key) = [mn_data["nw"]["$n"][storage_type][id][key] for n in 1:number_of_hours]
    repeatfirst(x) = vcat(x[1:1,:], x)
    p = plot(0:number_of_hours, repeatfirst(res_storage(candidate ? "ps_ne" : "ps"));
        yguide = "Power [p.u.]",
        xformatter = _ -> "",
        legend = :none,
        framestyle = :zerolines,
        seriestype = :steppre,
        fillrange = 0,
        linewidth = 2,
        seriescolor = HSLA(203,1,0.49,0.5),
    )
    plot!(p, 0:number_of_hours, hcat(repeatfirst(data_storage("charge_rating")), -repeatfirst(data_storage("discharge_rating")));
        seriestype=:steppre, linewidth=2, linestyle=:dot, seriescolor=HSLA(203,1,0.49,1)
    )
    e = plot(0:number_of_hours, vcat(mn_data["nw"]["1"][storage_type][id]["energy"], res_storage(candidate ? "se_ne" : "se"));
        yguide = "Energy [p.u.]",
        xguide = "Time [h]",
        legend = :none,
        framestyle = :zerolines,
        fillrange = 0,
        linewidth = 2,
        seriescolor = HSLA(15,0.73,0.58,0.5),
    )
    plot!(e, 0:number_of_hours, repeatfirst(data_storage("energy_rating"));
        seriestype=:steppre, linewidth=2, linestyle=:dot, seriescolor=HSLA(15,0.73,0.58,1)
    )
    plt = plot(p, e; layout = (2,1), plot_title = (candidate ? "Candidate storage" : "Storage") * " $id" )
    display(plt)
end
=#


## Test results

@testset "Storage model" begin

    @testset "Common features" begin

        # Case with a storage and a candidate storage. As demand exceeds by far the
        # available generation in the second half of the time horizon, both storage and
        # candidate storage are charged in the first half of the time horizon and discharged
        # in the second half. Involuntary curtailment of the load covers the remaining
        # excess of demand.
        data = _FP.parse_file(file)
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
        _FP.scale_data!(data; cost_scale_factor=1e-6)
        loadprofile = collect(range(0,2;length=number_of_hours))' # Create a load profile: ramp from 0 to 2 times the rated value of load
        time_series = _FP.create_profile_data(number_of_hours, data, loadprofile) # Compute time series by multiplying the rated value by the profile
        mn_data = _FP.make_multinetwork(data, time_series)
        result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)

        @testset "Existing storage" begin
            #plot_storage(mn_data, result; candidate=false)
            @test result["solution"]["nw"]["1"]["storage"]["1"]["sc"]               ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["2"]["storage"]["1"]["sc"]               ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["storage"]["1"]["sc"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["4"]["storage"]["1"]["sc"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["1"]["storage"]["1"]["sd"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["2"]["storage"]["1"]["sd"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["3"]["storage"]["1"]["sd"]               ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["4"]["storage"]["1"]["sd"]               ≈  0.6098 rtol=1e-3 # Less than 1.0 because of "charge_efficiency", "discharge_efficiency" and "self_discharge_rate"
            @test result["solution"]["nw"]["1"]["storage"]["1"]["ps"]               ≈  1.0    rtol=1e-3 # Storage model uses load convention: positive power when absorbed from the grid
            @test result["solution"]["nw"]["2"]["storage"]["1"]["ps"]               ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["storage"]["1"]["ps"]               ≈ -1.0    rtol=1e-3 # Storage model uses load convention: negative power when injected into the grid
            @test result["solution"]["nw"]["4"]["storage"]["1"]["ps"]               ≈ -0.6098 rtol=1e-3
            @test result["solution"]["nw"]["1"]["storage"]["1"]["se"]               ≈  2.898  rtol=1e-3 # Greater than 2.0 because refers to the end of the period
            @test result["solution"]["nw"]["2"]["storage"]["1"]["se"]               ≈  3.795  rtol=1e-3
            @test result["solution"]["nw"]["3"]["storage"]["1"]["se"]               ≈  2.680  rtol=1e-3
            @test result["solution"]["nw"]["4"]["storage"]["1"]["se"]               ≈  2.0    rtol=1e-3 # Must match "energy" parameter in data model
            @test haskey(result["solution"]["nw"]["4"]["storage"]["1"], "e_abs")    == false # Absorbed energy is not computed if is not bounded
        end

        @testset "Candidate storage" begin
            #plot_storage(mn_data, result; candidate=true)
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["investment"]    ≈  1.0    atol=1e-3 # Invested in candidate storage because it costs less than load curtailment
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["isbuilt"]       ≈  1.0    atol=1e-3 # Candidate storage is built accordingly to investment decision
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["sc_ne"]         ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["2"]["ne_storage"]["1"]["sc_ne"]         ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["ne_storage"]["1"]["sc_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["sc_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["sd_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["2"]["ne_storage"]["1"]["sd_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["3"]["ne_storage"]["1"]["sd_ne"]         ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["sd_ne"]         ≈  0.6098 rtol=1e-3 # Less than 1.0 because of "charge_efficiency", "discharge_efficiency" and "self_discharge_rate"
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["ps_ne"]         ≈  1.0    rtol=1e-3 # Storage model uses load convention: positive power when absorbed from the grid
            @test result["solution"]["nw"]["2"]["ne_storage"]["1"]["ps_ne"]         ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["ne_storage"]["1"]["ps_ne"]         ≈ -1.0    rtol=1e-3 # Storage model uses load convention: negative power when injected into the grid
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["ps_ne"]         ≈ -0.6098 rtol=1e-3
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["se_ne"]         ≈  2.898  rtol=1e-3 # Greater than 2.0 because refers to the end of the period
            @test result["solution"]["nw"]["2"]["ne_storage"]["1"]["se_ne"]         ≈  3.795  rtol=1e-3
            @test result["solution"]["nw"]["3"]["ne_storage"]["1"]["se_ne"]         ≈  2.680  rtol=1e-3
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["se_ne"]         ≈  2.0    rtol=1e-3 # Must match "energy" parameter in data model
            @test haskey(result["solution"]["nw"]["4"]["ne_storage"]["1"], "e_abs") == false # Absorbed energy is not computed if is not bounded
        end

    end

    @testset "Bounded absorption" begin

        # Same as base case, but the two storages have bounded absorption.
        data = _FP.parse_file(file)
        data["storage"]["1"]["max_energy_absorption"] = 1.0 # Limit the maximum energy absorption of existing storage
        data["ne_storage"]["1"]["max_energy_absorption"] = 1.0 # Limit the maximum energy absorption of candidate storage
        _FP.add_dimension!(data, :hour, number_of_hours)
        _FP.add_dimension!(data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
        _FP.scale_data!(data; cost_scale_factor=1e-6)
        loadprofile = collect(range(0,2;length=number_of_hours))' # Create a load profile: ramp from 0 to 2 times the rated value of load
        time_series = _FP.create_profile_data(number_of_hours, data, loadprofile) # Compute time series by multiplying the rated value by the profile
        mn_data = _FP.make_multinetwork(data, time_series)
        result = _FP.flex_tnep(mn_data, _FP.BFARadPowerModel, cbc)

        @testset "Existing storage" begin
            #plot_storage(mn_data, result; candidate=false)
            @test result["solution"]["nw"]["1"]["storage"]["1"]["ps"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["2"]["storage"]["1"]["ps"]               ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["storage"]["1"]["ps"]               ≈ -0.8020 rtol=1e-3
            @test result["solution"]["nw"]["4"]["storage"]["1"]["ps"]               ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["4"]["storage"]["1"]["e_abs"]            ≈  1.0    rtol=1e-3 # Must match "max_energy_absorption" parameter
        end

        @testset "Candidate storage" begin
            #plot_storage(mn_data, result; candidate=true)
            @test result["solution"]["nw"]["1"]["ne_storage"]["1"]["ps_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["2"]["ne_storage"]["1"]["ps_ne"]         ≈  1.0    rtol=1e-3
            @test result["solution"]["nw"]["3"]["ne_storage"]["1"]["ps_ne"]         ≈ -0.8020 rtol=1e-3
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["ps_ne"]         ≈  0.0    atol=1e-3
            @test result["solution"]["nw"]["4"]["ne_storage"]["1"]["e_abs_ne"]      ≈  1.0    rtol=1e-3 # Must match "max_energy_absorption" parameter
        end

    end

end;
