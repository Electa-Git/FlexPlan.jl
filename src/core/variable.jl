# To be used instead of _PM.variable_ne_branch_indicator() - supports Benders decomposition
function variable_ne_branch_indicator(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if haskey(_PM.ref(pm, nw), :benders) && _PM.ref(pm, nw, :benders, "first_nw") != nw
        first_nw = _PM.ref(pm, nw, :benders, "first_nw")
        z_branch_ne = _PM.var(pm, nw)[:branch_ne] = _PM.var(pm, first_nw)[:branch_ne]
    else
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
    end
    report && _IM.sol_component_value(pm, nw, :ne_branch, :built, _PM.ids(pm, nw, :ne_branch), z_branch_ne)
end
