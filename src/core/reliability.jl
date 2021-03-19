

function variable_demand_interruption(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pinter = _PM.var(pm, nw)[:pinter] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pinter",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pinter, _PM.ids(pm, nw, :load), pinter)
end


function constraint_contingency_pcurt(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int)
    pcurt_1 = _PM.var(pm, n_1, :pcurt, i)
    pcurt_2 = _PM.var(pm, n_2, :pcurt, i)

    JuMP.@constraint(pm.model, pcurt_1 == pcurt_2)
end