# Dispatchable and non-dispatchable generators


## Expressions

"Curtailed power of a non-dispatchable generator as the difference between its reference power and the generated power."
function expression_gen_curtailment(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, report::Bool=true)
    pgcurt = _PM.var(pm, nw)[:pgcurt] = Dict{Int,Any}(
        i => ndgen["pmax"] - _PM.var(pm,nw,:pg,i) for (i,ndgen) in _PM.ref(pm,nw,:ndgen)
    )
    if report
        _PM.sol_component_fixed(pm, nw, :gen, :pgcurt, _PM.ids(pm, nw, :dgen), 0.0)
        _PM.sol_component_value(pm, nw, :gen, :pgcurt, _PM.ids(pm, nw, :ndgen), pgcurt)
    end
end
