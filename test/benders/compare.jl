# Utilities to compare decomposition solutions with benchmark solutions

function run_and_time(
        data::Dict{String,<:Any},
        model_type::Type,
        optimizer::Union{_FP._MOI.AbstractOptimizer, _FP._MOI.OptimizerWithAttributes},
        build_method::Function;
        kwargs...
    )

    time_start = time()
    result = build_method(data, model_type, optimizer; kwargs...)
    @assert result["termination_status"] ∈ (_PM.OPTIMAL, _PM.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
    result["time"] = Dict{String,Any}("total" => time()-time_start)
    return result
end

function check_solution_correctness(benders_result, benchmark_result, obj_rtol, logger)
    benders_opt = benders_result["objective"]
    benchmark_opt = benchmark_result["objective"]
    if !isapprox(benders_opt, benchmark_opt; rtol=obj_rtol)
        warn(logger, @sprintf("Benders procedure failed to find an optimal solution within tolerance %.2e", obj_rtol))
        warn(logger, @sprintf("            (benders % 15.9g, benchmark % 15.9g, rtol %.2e)", benders_opt, benchmark_opt, benders_opt/benchmark_opt-1))
    end

    comp_name = Dict{String,String}(
        "ne_branch"   => "AC branch",
        "branchdc_ne" => "DC branch",
        "convdc_ne"   => "converter",
        "ne_storage"  => "storage",
        "load"        => "flex load"
    )
    benders_sol = Dict(year => benders_result["solution"]["nw"]["$n"] for (year, n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1)))
    benchmark_sol = Dict(year => benchmark_result["solution"]["nw"]["$n"] for (year, n) in enumerate(_FP.nw_ids(data; hour=1, scenario=1)))
    for y in keys(benchmark_sol)
        for (comp, name) in comp_name
        if haskey(benchmark_sol[y], comp)
            for idx in keys(benchmark_sol[y][comp])
                    benchmark_value = benchmark_sol[y][comp][idx]["investment"]
                    benders_value = benders_sol[y][comp][idx]["investment"]
                    if !isapprox(benders_value, benchmark_value, atol=1e-1)
                        warn(logger, "In year $y, the investment decision for $name $idx does not match (Benders $(round(Int,benders_value)), benchmark $(round(Int,benchmark_value)))")
                    end
                end
            end
        end
    end
end
