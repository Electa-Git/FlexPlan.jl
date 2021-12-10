# Variables and constraints related to flexible loads



## Variables

function variable_flexible_demand(pm::_PM.AbstractPowerModel; kwargs...)
    variable_total_flex_demand(pm; kwargs...)
    variable_demand_reduction(pm; kwargs...)
    variable_energy_not_consumed(pm; kwargs...)
    variable_demand_shifting_upwards(pm; kwargs...)
    variable_total_demand_shifting_upwards(pm; kwargs...)
    variable_demand_shifting_downwards(pm; kwargs...)
    variable_total_demand_shifting_downwards(pm; kwargs...)
    variable_demand_curtailment(pm; kwargs...)
    variable_flexible_demand_indicator(pm; kwargs..., relax=true)
    variable_flexible_demand_investment(pm; kwargs...)
end

"Variable: whether flexible demand is enabled at a load point"
function variable_flexible_demand_indicator(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
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
    else
        z = _PM.var(pm, nw)[:z_flex] = _PM.var(pm, first_n)[:z_flex]
    end
    report && _IM.sol_component_value(pm, nw, :load, :isflex, _PM.ids(pm, nw, :load), z)
end

"Variable: investment decision to enable flexible demand at a load point"
function variable_flexible_demand_investment(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            investment = _PM.var(pm, nw)[:z_flex_investment] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_z_flex_investment",
                binary = true,
                start = 0
            )
        else
            investment = _PM.var(pm, nw)[:z_flex_investment] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_z_flex_investment",
                lower_bound = 0,
                upper_bound = 1,
                start = 0
            )
        end
    else
        investment = _PM.var(pm, nw)[:z_flex_investment] = _PM.var(pm, first_n)[:z_flex_investment]
    end
    report && _IM.sol_component_value(pm, nw, :load, :investment, _PM.ids(pm, nw, :load), investment)
end

function variable_total_flex_demand(pm::_PM.AbstractPowerModel; kwargs...)
    variable_total_flex_demand_active(pm; kwargs...)
    variable_total_flex_demand_reactive(pm; kwargs...)
end

"Variable for the actual (flexible) real load demand at each load point and each time step"
function variable_total_flex_demand_active(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pflex = _PM.var(pm, nw)[:pflex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pflex",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * (1 + _PM.ref(pm, nw, :load, i, "p_shift_up_max")), # not strictly nessesary and could be removed - redundant due to other bounds
        start = _PM.comp_start_value(_PM.ref(pm, nw, :load, i), "pd")
    )

    report && _IM.sol_component_value(pm, nw, :load, :pflex, _PM.ids(pm, nw, :load), pflex)
end

function variable_total_flex_demand_reactive(pm::_PM.AbstractActivePowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
end

"Variable for the actual (flexible) reactive load demand at each load point and each time step"
function variable_total_flex_demand_reactive(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    qflex = _PM.var(pm, nw)[:qflex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_qflex",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :load, i), "qd")
    )

    report && _IM.sol_component_value(pm, nw, :load, :qflex, _PM.ids(pm, nw, :load), qflex)
end

"Variable for load curtailment (i.e. involuntary demand reduction) at each load point and each time step"
function variable_demand_curtailment(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    pcurt = _PM.var(pm, nw)[:pcurt] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pcurt",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pcurt, _PM.ids(pm, nw, :load), pcurt)
end

"Variable for the power not consumed (voluntary load reduction) at each load point and each time step"
function variable_demand_reduction(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ p_red_max ≤ 1) of the
    # reference load demand pd for that time step. (Thus, while p_red_max is a scalar input
    # parameter, the variable bounds become a time series.)
    pnce = _PM.var(pm, nw)[:pnce] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pnce",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_red_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pnce, _PM.ids(pm, nw, :load), pnce)
end

"Variable for keeping track of the energy not consumed (i.e. the accumulated voluntary load reduction) over the operational planning horizon at each load point"
function variable_energy_not_consumed(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    ence = _PM.var(pm, nw)[:ence] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_ence",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "e_nce_max") * _PM.ref(pm, first_nw, :load, i, "ed_tot"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :ence, _PM.ids(pm, nw, :load), ence)
end

"Variable for the upward demand shifting at each load point and each time step"
function variable_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ p_shift_up_max ≤ 1) of the
    # reference load demand pd for that time step. (Thus, while p_shift_up_max is a scalar
    # input parameter, the variable bounds become a time series.)
    pshift_up = _PM.var(pm, nw)[:pshift_up] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_up",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_up_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_up, _PM.ids(pm, nw, :load), pshift_up)
end

"Variable for keeping track of the accumulated upward demand shifting over the operational planning horizon at each load point"
function variable_total_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    pshift_up_tot = _PM.var(pm, nw)[:pshift_up_tot] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_up_tot",
        lower_bound = 0,
        # The accumulated load shifted up should equal the accumulated load shifted down, so this constraint is probably redundant
        upper_bound = _PM.ref(pm, nw, :load, i, "p_shift_down_tot_max") * _PM.ref(pm, first_nw, :load, i, "ed_tot"),
        start = 0
    )
    report && _IM.sol_component_value(pm, nw, :load, :pshift_up_tot, _PM.ids(pm, nw, :load), pshift_up_tot)
end

"Variable for the downward demand shifting at each load point and each time step"
function variable_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ p_shift_down_max ≤ 1) of the
    # reference load demand pd for that time step. (Thus, while p_shift_down_max is a scalar
    # input parameter, the variable bounds become a time series.)
    pshift_down = _PM.var(pm, nw)[:pshift_down] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_down",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :load, i, "p_shift_down_max"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_down, _PM.ids(pm, nw, :load), pshift_down)
end

"Variable for keeping track of the accumulated upward demand shifting over the operational planning horizon at each load point"
function variable_total_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    pshift_down_tot = _PM.var(pm, nw)[:pshift_down_tot] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pshift_down_tot",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "p_shift_down_tot_max") * _PM.ref(pm, first_nw, :load, i, "ed_tot"),
        start = 0
    )

    report && _IM.sol_component_value(pm, nw, :load, :pshift_down_tot, _PM.ids(pm, nw, :load), pshift_down_tot)
end



## Constraint templates

function constraint_flexible_demand_activation(pm::_PM.AbstractPowerModel, i::Int, prev_nws::Vector{Int}, nw::Int)
    investment_horizon = [nw]
    lifetime = _PM.ref(pm, nw, :load, i, "lifetime")
    for n in Iterators.reverse(prev_nws[1:min(lifetime-1,length(prev_nws))])
        i in _PM.ids(pm, n, :load) ? push!(investment_horizon, n) : break
    end
    constraint_flexible_demand_activation(pm, nw, i, investment_horizon)
end

function constraint_fixed_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_fixed_demand(pm, nw, i)
end

function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_flex_bounds_ne(pm, nw, i)
end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    load     = _PM.ref(pm, nw, :load, i)
    pd       = load["pd"]
    pf_angle = get(load, "pf_angle", 0.0) # power factor angle, in radians
    constraint_total_flexible_demand(pm, nw, i, pd, pf_angle)
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

function constraint_shift_duration(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    constraint_shift_duration_up(pm, i, first_hour_nw, nw)
    constraint_shift_duration_down(pm, i, first_hour_nw, nw)
end

function constraint_shift_duration_up(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    load = _PM.ref(pm, nw, :load, i)
    start_grace = max(nw-load["t_grace_up"],first_hour_nw)
    constraint_shift_duration_up(pm, nw, i, start_grace, nothing)
end

function constraint_shift_duration_down(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    load = _PM.ref(pm, nw, :load, i)
    start_grace = max(nw-load["t_grace_down"],first_hour_nw)
    constraint_shift_duration_down(pm, nw, i, start_grace, nothing)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_up_state_initial(pm, nw, i, time_elapsed)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_up_state(pm, nw_1, nw_2, i, time_elapsed)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_down_state_initial(pm, nw, i, time_elapsed)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_shift_down_state(pm, nw_1, nw_2, i, time_elapsed)
end

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_shift_state_final(pm, nw, i)
end



## Constraint implementations

function constraint_flexible_demand_activation(pm::_PM.AbstractPowerModel, n::Int, i::Int, horizon::Vector{Int})
    indicator = _PM.var(pm, n, :z_flex, i)
    investments = _PM.var.(Ref(pm), horizon, :z_flex_investment, i)

    # Activate the flexibility depending on the investment decisions in the load's horizon.
    JuMP.@constraint(pm.model, indicator == sum(investments))
end

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

function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pnce = _PM.var(pm, n, :pnce, i)
    z = _PM.var(pm, n, :z_flex, i)

    pshift_up_max = JuMP.upper_bound(pshift_up)
    pshift_down_max = JuMP.upper_bound(pshift_down)
    pnce_max = JuMP.upper_bound(pnce)

    # Bounds on the demand flexibility decision variables (demand shifting and voluntary load reduction)
    JuMP.@constraint(pm.model, pshift_up <= pshift_up_max * z)
    JuMP.@constraint(pm.model, pshift_down <= pshift_down_max * z)
    JuMP.@constraint(pm.model, pnce <= pnce_max * z)

end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, n::Int, i, pd, pf_angle)
    pflex       = _PM.var(pm, n, :pflex, i)
    qflex       = _PM.var(pm, n, :qflex, i)
    pnce        = _PM.var(pm, n, :pnce, i)
    pshift_up   = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pcurt       = _PM.var(pm, n, :pcurt, i)

    # The actual (flexible) demand is the reference demand pd plus the contributions from all the demand flexibility decision variables
    JuMP.@constraint(pm.model, pflex == pd - pnce + pshift_up - pshift_down - pcurt)

    # The actual reactive load demand is fixed by the actual real load demand and the power factor angle
    # (which is constant for each load point)
    JuMP.@constraint(pm.model, qflex == tan(pf_angle) * pflex)
end

function constraint_total_flexible_demand(pm::_PM.AbstractActivePowerModel, n::Int, i, pd, pf_angle)
    pflex       = _PM.var(pm, n, :pflex, i)
    pnce        = _PM.var(pm, n, :pnce, i)
    pshift_up   = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pcurt       = _PM.var(pm, n, :pcurt, i)

    # The actual (flexible) demand is the reference demand pd plus the contributions from all the demand flexibility decision variables
    JuMP.@constraint(pm.model, pflex == pd - pnce + pshift_up - pshift_down - pcurt)
end

function constraint_ence_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pnce = _PM.var(pm, n, :pnce, i)
    ence = _PM.var(pm, n, :ence, i)

    # Initialization of not consumed energy variable (accumulated voluntary load reduction)
    JuMP.@constraint(pm.model, ence == time_elapsed * pnce)
end

function constraint_ence_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pnce = _PM.var(pm, n_2, :pnce, i)
    ence_2 = _PM.var(pm, n_2, :ence, i)
    ence_1 = _PM.var(pm, n_1, :ence, i)

    # Accumulation of not consumed energy (accumulation of voluntary load reduction for each time step)
    JuMP.@constraint(pm.model, ence_2 - ence_1 == time_elapsed * pnce)
end

function constraint_shift_duration_up(pm::_PM.AbstractPowerModel, n::Int, i::Int, start_grace::Int, placeholder::Nothing) # Placeholder is to distinguish constraint template and constraint implementation through multiple dispatch
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_up_max = JuMP.upper_bound(pshift_up)

    # Applying grace/recovery period for upward demand shifting: Demand shifted for one time step reduced the demand that can
    # be shifted in subsequent time steps
    JuMP.@constraint(pm.model, pshift_up <= pshift_up_max - sum(_PM.var(pm, t, :pshift_up, i) for t in start_grace:n-1))
end

function constraint_shift_duration_down(pm::_PM.AbstractPowerModel, n::Int, i::Int, start_grace::Int, placeholder::Nothing) # Placeholder is to distinguish constraint template and constraint implementation through multiple dispatch
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pshift_down_max = JuMP.upper_bound(pshift_down)

    # Applying grace/recovery period for downward demand shifting: Demand shifted for one time step reduced the demand that can
    # be shifted in subsequent time steps
    JuMP.@constraint(pm.model, pshift_down <= pshift_down_max - sum(_PM.var(pm, t, :pshift_down, i) for t in start_grace:n-1))
end

function constraint_shift_up_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    pshift_up_tot = _PM.var(pm, n, :pshift_up_tot, i)

    # Initialization of accumulated upward demand shifting variable
    JuMP.@constraint(pm.model, pshift_up_tot == time_elapsed * pshift_up)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pshift_up = _PM.var(pm, n_2, :pshift_up, i)
    pshift_up_tot_2 = _PM.var(pm, n_2, :pshift_up_tot, i)
    pshift_up_tot_1 = _PM.var(pm, n_1, :pshift_up_tot, i)

    # Accumulation of upward demand shifting for each time step
    JuMP.@constraint(pm.model, pshift_up_tot_2 - pshift_up_tot_1 == time_elapsed * pshift_up)
end

function constraint_shift_down_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pshift_down_tot = _PM.var(pm, n, :pshift_down_tot, i)

    # Initialization of accumulated downward demand shifting variable
    JuMP.@constraint(pm.model, pshift_down_tot == time_elapsed * pshift_down)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pshift_down = _PM.var(pm, n_2, :pshift_down, i)
    pshift_down_tot_2 = _PM.var(pm, n_2, :pshift_down_tot, i)
    pshift_down_tot_1 = _PM.var(pm, n_1, :pshift_down_tot, i)

    # Accumulation of downward demand shifting for each time step
    JuMP.@constraint(pm.model, pshift_down_tot_2 - pshift_down_tot_1 == time_elapsed * pshift_down)
end

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    pshift_up_tot = _PM.var(pm, n, :pshift_up_tot, i)
    pshift_down_tot = _PM.var(pm, n, :pshift_down_tot, i)

    # The accumulated upward demand shifting over the operational planning horizon should equal the accumulated downward
    # demand shifting (since this is demand shifted and not reduced or curtailed)
    JuMP.@constraint(pm.model, pshift_up_tot == pshift_down_tot)
end
