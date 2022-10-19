# To be used instead of _PM.variable_ne_branch_indicator() - supports deduplication of variables
function variable_ne_branch_indicator(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            z_branch_ne = _PM.var(pm, nw)[:branch_ne] = JuMP.@variable(pm.model,
                [l in _PM.ids(pm, nw, :ne_branch)], base_name="$(nw)_branch_ne",
                binary = true,
                start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_branch, l), "branch_tnep_start", 1.0)
            )
        else
            z_branch_ne = _PM.var(pm, nw)[:branch_ne] = JuMP.@variable(pm.model,
                [l in _PM.ids(pm, nw, :ne_branch)], base_name="$(nw)_branch_ne",
                lower_bound = 0.0,
                upper_bound = 1.0,
                start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_branch, l), "branch_tnep_start", 1.0)
            )
        end
    else
        z_branch_ne = _PM.var(pm, nw)[:branch_ne] = _PM.var(pm, first_n)[:branch_ne]
    end
    report && _PM.sol_component_value(pm, nw, :ne_branch, :built, _PM.ids(pm, nw, :ne_branch), z_branch_ne)
end

function variable_ne_branch_investment(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            investment = _PM.var(pm, nw)[:branch_ne_investment] = JuMP.@variable(pm.model,
                [l in _PM.ids(pm, nw, :ne_branch)], base_name="$(nw)_branch_ne_investment",
                binary = true,
                start = 0
            )
        else
            investment = _PM.var(pm, nw)[:branch_ne_investment] = JuMP.@variable(pm.model,
                [l in _PM.ids(pm, nw, :ne_branch)], base_name="$(nw)_branch_ne_investment",
                lower_bound = 0.0,
                upper_bound = 1.0,
                start = 0
            )
        end
    else
        investment = _PM.var(pm, nw)[:branch_ne_investment] = _PM.var(pm, first_n)[:branch_ne_investment]
    end
    report && _PM.sol_component_value(pm, nw, :ne_branch, :investment, _PM.ids(pm, nw, :ne_branch), investment)
end
