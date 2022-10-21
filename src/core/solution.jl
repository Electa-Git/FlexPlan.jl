"""
    sol_pm!(pm, solution)

Make `pm` available in `solution["pm"]`.

If `sol_pm!` is used as solution processor when running a model, then `pm` will be available
in `result["solution"]["pm"]` (where `result` is the name of the returned Dict) after the
optimization has ended.
"""
function sol_pm!(pm::_PM.AbstractPowerModel, solution::Dict{String,Any})
    solution["pm"] = pm
end
