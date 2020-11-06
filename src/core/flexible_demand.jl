##################################################################################
#### DEFINTION OF NEW VARIABLES FOR STORAGE INVESTMENTS ACCODING TO FlexPlan MODEL
##################################################################################
function variable_flexible_demand(pm::_PM.AbstractPowerModel; kwargs...)
    variable_total_flex_demand(pm; kwargs...)
    variable_demand_reduction(pm; kwargs...)
    variable_energy_not_consumed(pm; kwargs...)
    variable_demand_shifting_upwards(pm; kwargs...)
    variable_total_demand_shifting_upwards(pm; kwargs...)
    variable_demand_shifting_downwards(pm; kwargs...)
    variable_total_demand_shifting_downwards(pm; kwargs...)
    variable_demand_curtailment(pm; kwargs...)
    variable_flexible_demand_investment(pm; kwargs...)
end
#
function variable_total_flex_demand(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pflex = _PM.var(pm, nw)[:pflex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pflex",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * (1 + _PM.ref(pm, nw, :load, i, "p_shift_up_max")),
        start = _PM.comp_start_value(_PM.ref(pm, nw, :load, i), "pd")
    )

    report && _IM.sol_component_value(pm, nw, :load, :pflex, _PM.ids(pm, nw, :load), pflex)
end

function variable_demand_reduction(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pnce = _PM.var(pm, nw)[:pnce] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pnce",
        lower_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_red_min"),
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_red_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pnce, _PM.ids(pm, nw, :load), pnce)
end

function variable_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pshift_up = _PM.var(pm, nw)[:pshift_up] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_up",
        lower_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_up_min"),
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_up_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_up, _PM.ids(pm, nw, :load), pshift_up)
end

function variable_total_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pshift_up_tot = _PM.var(pm, nw)[:pshift_up_tot] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_up_tot",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_up_max") * length(_PM.nw_ids(pm)), # to be updated
        start = 0
    )
    report && _IM.sol_component_value(pm, nw, :load, :pshift_up_tot, _PM.ids(pm, nw, :load), pshift_up_tot)
end

function variable_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pshift_down = _PM.var(pm, nw)[:pshift_down] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_down",
        lower_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_down_min"),
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_down_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_down, _PM.ids(pm, nw, :load), pshift_down)
end

function variable_total_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pshift_down_tot = _PM.var(pm, nw)[:pshift_down_tot] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_down_tot",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_down_max") * length(_PM.nw_ids(pm)), # to be updated
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_down_tot, _PM.ids(pm, nw, :load), pshift_down_tot)
end

function variable_energy_not_consumed(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    ence = _PM.var(pm, nw)[:ence] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_ence",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "e_nce_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :ence, _PM.ids(pm, nw, :load), ence)
end

function variable_demand_curtailment(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pcurt = _PM.var(pm, nw)[:pcurt] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pcurt",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pcurt, _PM.ids(pm, nw, :load), pcurt)
end

function variable_flexible_demand_investment(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if !relax
        z = _PM.var(pm, nw)[:z_flex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_z_flex",
        binary = true,
        start = 0
        )
    else
        z = _PM.var(pm, nw)[:z_flex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_z_flex",
        lower_bound = 0,
        upper_bound = 1,
        start = 0
        )
    end
    report && _IM.sol_component_value(pm, nw, :load, :isflex, _PM.ids(pm, nw, :load), z)
 end
# ####################################################
# Constraint Templates: They are used to do all data manipuations and return a function with the same name, 
# this way the constraint itself only containts the mathematical formulation
# ###################################################
function constraint_fixed_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_fixed_demand(pm, nw, i)
end

function constraint_shift_duration(pm::_PM.AbstractPowerModel, n_2::Int, network_ids, i::Int)
    constraint_shift_duration_up(pm, n_2, network_ids, i)
    constraint_shift_duration_down(pm, n_2, network_ids, i)
end
#
function constraint_shift_duration_up(pm::_PM.AbstractPowerModel, n_2::Int, n_idx, i::Int)
    load = _PM.ref(pm, n_2, :load, i)

    constraint_shift_duration_up(pm, n_2, n_idx, i, load["t_grace_up"])
end
#
function constraint_shift_duration_down(pm::_PM.AbstractPowerModel, n_2::Int, n_idx, i::Int)
    load = _PM.ref(pm, n_2, :load, i)

    constraint_shift_duration_down(pm, n_2, n_idx, i, load["t_grace_down"])
end


function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_flex_bounds_ne(pm, nw, i)
end

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_shift_state_final(pm, nw, i)
end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    load = _PM.ref(pm, nw, :load, i)
    constraint_total_flexible_demand(pm, nw, i, load["pd"])
end

function constraint_ence_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    load = _PM.ref(pm, nw, :load, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_ence_state_initial(pm, nw, i, time_elapsed)
end

function constraint_ence_state(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    load = _PM.ref(pm, nw_2, :load, i)

    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    constraint_ence_state(pm, nw_1, nw_2, i, time_elapsed)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_up_state_initial(pm, nw, i)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_down_state_initial(pm, nw, i)
end
#
# ####################################################
# ############### Constraints
# ###################################################
function constraint_fixed_demand(pm::_PM.AbstractPowerModel, n::Int, i)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pshift_up_tot = _PM.var(pm, n, :pshift_up_tot, i)
    pshift_down_tot = _PM.var(pm, n, :pshift_down_tot, i)
    pnce = _PM.var(pm, n, :pnce, i)
    ence = _PM.var(pm, n, :ence, i)
    z_flex = _PM.var(pm, n, :z_flex, i)

    JuMP.@constraint(pm.model, pshift_up == 0)
    JuMP.@constraint(pm.model, pshift_down == 0)
    JuMP.@constraint(pm.model, pshift_up_tot == 0)
    JuMP.@constraint(pm.model, pshift_down_tot == 0)
    JuMP.@constraint(pm.model, pnce == 0)
    JuMP.@constraint(pm.model, ence == 0)
    JuMP.@constraint(pm.model, z_flex == 0)
end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, n::Int, i, pd)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pnce = _PM.var(pm, n, :pnce, i)
    pflex = _PM.var(pm, n, :pflex, i)
    pcurt = _PM.var(pm, n, :pcurt, i)

    JuMP.@constraint(pm.model, pflex == pd - pnce + pshift_up - pshift_down - pcurt)
end


function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pnce = _PM.var(pm, n, :pnce, i)
    z = _PM.var(pm, n, :z_flex, i)

    pshift_up_min = JuMP.lower_bound(pshift_up)
    pshift_up_max = JuMP.upper_bound(pshift_up)
    pshift_down_min = JuMP.lower_bound(pshift_down)
    pshift_down_max = JuMP.upper_bound(pshift_down)
    pnce_min = JuMP.lower_bound(pnce)
    pnce_max = JuMP.upper_bound(pnce)


    JuMP.@constraint(pm.model, pshift_up  <= pshift_up_max * z)
    JuMP.@constraint(pm.model, pshift_up  >= pshift_up_min * z)
    JuMP.@constraint(pm.model, pshift_down  <= pshift_down_max * z)
    JuMP.@constraint(pm.model, pshift_down  >= pshift_down_min * z)
    JuMP.@constraint(pm.model, pnce  <= pnce_max * z)
    JuMP.@constraint(pm.model, pnce  >= pnce_min * z)

end

function constraint_ence_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pnce = _PM.var(pm, n, :pnce, i)
    ence = _PM.var(pm, n, :ence, i)

    JuMP.@constraint(pm.model, ence == time_elapsed * pnce)
end

function constraint_ence_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pnce = _PM.var(pm, n_2, :pnce, i)
    ence_2 = _PM.var(pm, n_2, :ence, i)
    ence_1 = _PM.var(pm, n_1, :ence, i)

    JuMP.@constraint(pm.model, ence_2 - ence_1 == time_elapsed * pnce)
end

function constraint_shift_up_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_up_tot = _PM.var(pm, n, :pshift_up_tot, i)

    JuMP.@constraint(pm.model, pshift_up_tot == pshift_up)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int)
    pshift_up = _PM.var(pm, n_2, :pshift_up, i)
    pshift_up_tot_2 = _PM.var(pm, n_2, :pshift_up_tot, i)
    pshift_up_tot_1 = _PM.var(pm, n_1, :pshift_up_tot, i)

    JuMP.@constraint(pm.model, pshift_up_tot_2 - pshift_up_tot_1 == pshift_up)
end

function constraint_shift_down_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pshift_down_tot = _PM.var(pm, n, :pshift_down_tot, i)

    JuMP.@constraint(pm.model, pshift_down_tot == pshift_down)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int)
    pshift_down = _PM.var(pm, n_2, :pshift_down, i)
    pshift_down_tot_2 = _PM.var(pm, n_2, :pshift_down_tot, i)
    pshift_down_tot_1 = _PM.var(pm, n_1, :pshift_down_tot, i)

    JuMP.@constraint(pm.model, pshift_down_tot_2 - pshift_down_tot_1 == pshift_down)
end

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_up_tot = _PM.var(pm, n, :pshift_up_tot, i)
    pshift_down_tot = _PM.var(pm, n, :pshift_down_tot, i)

    JuMP.@constraint(pm.model, pshift_up_tot == pshift_down_tot)
end

function constraint_flex_investment(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int)
    z_1 = _PM.var(pm, n_1, :z_flex, i)
    z_2 = _PM.var(pm, n_2, :z_flex, i)

    JuMP.@constraint(pm.model, z_1 == z_2)
end

function constraint_shift_duration_up(pm, n_2, n_idx, i, t_grace)
    pshift_up = _PM.var(pm, n_2, :pshift_up, i)
    pshift_up_max = JuMP.upper_bound(pshift_up)
    t = max(1, n_2 - t_grace)
    # JuMP.@constraint(pm.model, pshift_up <= pshift_up_max - sum(_PM.var(pm, n, :pshift_up_tot, i) for n in n_idx[n_2 - t_grace:n_2-1])) #ToDo verify that shiting constraint is correct
    JuMP.@constraint(pm.model, pshift_up <= pshift_up_max - _PM.var(pm, t, :pshift_up_tot, i))
end

function constraint_shift_duration_down(pm, n_2, n_idx, i, t_grace)
    pshift_down = _PM.var(pm, n_2, :pshift_down, i)
    pshift_down_max = JuMP.upper_bound(pshift_down)
    t = max(1, n_2 - t_grace)
    # JuMP.@constraint(pm.model, pshift_down <= pshift_down_max - sum(_PM.var(pm, n, :pshift_down_tot, i) for n in n_idx[n_2 - t_grace:n_2-1])) #ToDo verify that shiting constraint is correct
    JuMP.@constraint(pm.model, pshift_down <= pshift_down_max - _PM.var(pm, t, :pshift_down_tot, i))
end