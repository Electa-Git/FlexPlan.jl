# To be used instead of _PMACDC.variable_branch_ne() - supports Benders decomposition
function variable_branch_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if haskey(_PM.ref(pm, nw), :benders) && _PM.ref(pm, nw, :benders, "first_nw") != nw
        first_nw = _PM.ref(pm, nw, :benders, "first_nw")
        Z_dc_branch_ne = _PM.var(pm, nw)[:branchdc_ne] = _PM.var(pm, first_nw)[:branchdc_ne]
    else
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
    end
    report && _IM.sol_component_value(pm, nw, :branchdc_ne, :isbuilt, _PM.ids(pm, nw, :branchdc_ne), Z_dc_branch_ne)
end
