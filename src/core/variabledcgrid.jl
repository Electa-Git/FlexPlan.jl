# To be used instead of _PMACDC.variable_branch_ne() - supports deduplication of variables
function variable_ne_branchdc_indicator(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            Z_dc_branch_ne = _PM.var(pm, nw)[:branchdc_ne] = JuMP.@variable(pm.model, #branch_ne is also name in PowerModels, branchdc_ne is candidate branches
                [l in _PM.ids(pm, nw, :branchdc_ne)], base_name="$(nw)_branch_ne",
                binary = true,
                start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc_ne, l), "convdc_tnep_start",  0.0)
            )
        else
            Z_dc_branch_ne = _PM.var(pm, nw)[:branchdc_ne] = JuMP.@variable(pm.model, #branch_ne is also name in PowerModels, branchdc_ne is candidate branches
                [l in _PM.ids(pm, nw, :branchdc_ne)], base_name="$(nw)_branch_ne",
                lower_bound = 0,
                upper_bound = 1,
                start = _PM.comp_start_value(_PM.ref(pm, nw, :branchdc_ne, l), "convdc_tnep_start",  0.0)
            )
        end
    else
        Z_dc_branch_ne = _PM.var(pm, nw)[:branchdc_ne] = _PM.var(pm, first_n)[:branchdc_ne]
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc_ne, :isbuilt, _PM.ids(pm, nw, :branchdc_ne), Z_dc_branch_ne)
end

function variable_ne_branchdc_investment(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            investment = _PM.var(pm, nw)[:branchdc_ne_investment] = JuMP.@variable(pm.model, #branch_ne is also name in PowerModels, branchdc_ne is candidate branches
                [l in _PM.ids(pm, nw, :branchdc_ne)], base_name="$(nw)_branch_ne_investment",
                binary = true,
                start = 0
            )
        else
            investment = _PM.var(pm, nw)[:branchdc_ne_investment] = JuMP.@variable(pm.model, #branch_ne is also name in PowerModels, branchdc_ne is candidate branches
                [l in _PM.ids(pm, nw, :branchdc_ne)], base_name="$(nw)_branch_ne_investment",
                lower_bound = 0,
                upper_bound = 1,
                start = 0
            )
        end
    else
        investment = _PM.var(pm, nw)[:branchdc_ne_investment] = _PM.var(pm, first_n)[:branchdc_ne_investment]
    end
    report && _IM.sol_component_value(pm, _PM.pm_it_sym, nw, :branchdc_ne, :investment, _PM.ids(pm, nw, :branchdc_ne), investment)
end
