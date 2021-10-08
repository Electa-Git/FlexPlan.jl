# Functions to make performance tests of decomposition implementations

using Dates

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
