# Variables and constraints related to flexible loads



## Variables

function variable_flexible_demand(pm::_PM.AbstractPowerModel; kwargs...)
    variable_total_flex_demand(pm; kwargs...)
    variable_demand_reduction(pm; kwargs...)
    variable_demand_shifting_upwards(pm; kwargs...)
    variable_demand_shifting_downwards(pm; kwargs...)
    variable_demand_curtailment(pm; kwargs...)
    variable_flexible_demand_indicator(pm; kwargs..., relax=true)
    variable_flexible_demand_investment(pm; kwargs...)
end

"Variable: whether flexible demand is enabled at a flex load point"
function variable_flexible_demand_indicator(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            z = _PM.var(pm, nw)[:z_flex] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_z_flex",
                binary = true,
                start = 0
            )
        else
            z = _PM.var(pm, nw)[:z_flex] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_z_flex",
                lower_bound = 0,
                upper_bound = 1,
                start = 0
            )
        end
    else
        z = _PM.var(pm, nw)[:z_flex] = _PM.var(pm, first_n)[:z_flex]
    end
    if report
        _PM.sol_component_value(pm, nw, :load, :flex, _PM.ids(pm, nw, :flex_load), z)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :flex, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable: investment decision to enable flexible demand at a flex load point"
function variable_flexible_demand_investment(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, relax::Bool=false, report::Bool=true)
    first_n = first_id(pm, nw, :hour, :scenario)
    if nw == first_n
        if !relax
            investment = _PM.var(pm, nw)[:z_flex_investment] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_z_flex_investment",
                binary = true,
                start = 0
            )
        else
            investment = _PM.var(pm, nw)[:z_flex_investment] = JuMP.@variable(pm.model,
                [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_z_flex_investment",
                lower_bound = 0,
                upper_bound = 1,
                start = 0
            )
        end
    else
        investment = _PM.var(pm, nw)[:z_flex_investment] = _PM.var(pm, first_n)[:z_flex_investment]
    end
    if report
        _PM.sol_component_value(pm, nw, :load, :investment, _PM.ids(pm, nw, :flex_load), investment)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :investment, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

function variable_total_flex_demand(pm::_PM.AbstractPowerModel; kwargs...)
    variable_total_flex_demand_active(pm; kwargs...)
    variable_total_flex_demand_reactive(pm; kwargs...)
end

"Variable for the actual (flexible) real load demand at each load point and each time step"
function variable_total_flex_demand_active(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pflex = _PM.var(pm, nw)[:pflex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pflex",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * (1 + get(_PM.ref(pm, nw, :load, i), "pshift_up_rel_max", 0.0)), # Not strictly necessary: redundant due to other bounds
        start = _PM.comp_start_value(_PM.ref(pm, nw, :load, i), "pd")
    )
    report && _PM.sol_component_value(pm, nw, :load, :pflex, _PM.ids(pm, nw, :load), pflex)
end

function variable_total_flex_demand_reactive(pm::_PM.AbstractActivePowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
end

"Variable for the actual (flexible) reactive load demand at each load point and each time step"
function variable_total_flex_demand_reactive(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    qflex = _PM.var(pm, nw)[:qflex] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_qflex",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :load, i), "qd")
    )
    report && _PM.sol_component_value(pm, nw, :load, :qflex, _PM.ids(pm, nw, :load), qflex)
end

"Variable for load curtailment (i.e. involuntary demand reduction) at each load point and each time step"
function variable_demand_curtailment(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    pcurt = _PM.var(pm, nw)[:pcurt] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :load)], base_name="$(nw)_pcurt",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd"),
        start = 0
    )
    report && _PM.sol_component_value(pm, nw, :load, :pcurt, _PM.ids(pm, nw, :load), pcurt)
end

"Variable for the power not consumed (voluntary load reduction) at each flex load point and each time step"
function variable_demand_reduction(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ pred_rel_max ≤ 1) of the
    # reference load demand pd for that time step. (Thus, while pred_rel_max is a scalar
    # input parameter, the variable bounds become a time series.)
    pred = _PM.var(pm, nw)[:pred] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_pred",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :flex_load, i, "pred_rel_max"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :pred, _PM.ids(pm, nw, :flex_load), pred)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :pred, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable for keeping track of the energy not consumed (i.e. the accumulated voluntary load reduction) over the operational planning horizon at each flex load point"
function variable_energy_not_consumed(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    ered = _PM.var(pm, nw)[:ered] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_ered",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :flex_load, i, "ered_rel_max") * _PM.ref(pm, first_nw, :flex_load, i, "ed"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :ered, _PM.ids(pm, nw, :flex_load), ered)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :ered, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable for the upward demand shifting at each flex load point and each time step"
function variable_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ pshift_up_rel_max ≤ 1) of the
    # reference load demand pd for that time step. (Thus, while pshift_up_rel_max is a
    # scalar input parameter, the variable bounds become a time series.)
    pshift_up = _PM.var(pm, nw)[:pshift_up] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_pshift_up",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :flex_load, i, "pshift_up_rel_max"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :pshift_up, _PM.ids(pm, nw, :flex_load), pshift_up)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :pshift_up, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable for keeping track of the accumulated upward demand shifting over the operational planning horizon at each flex_load point"
function variable_total_demand_shifting_upwards(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    eshift_up = _PM.var(pm, nw)[:eshift_up] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_eshift_up",
        lower_bound = 0,
        # The accumulated load shifted up should equal the accumulated load shifted down, so this constraint is probably redundant
        upper_bound = _PM.ref(pm, nw, :flex_load, i, "eshift_rel_max") * _PM.ref(pm, first_nw, :flex_load, i, "ed"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :eshift_up, _PM.ids(pm, nw, :flex_load), eshift_up)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :eshift_up, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable for the downward demand shifting at each flex load point and each time step"
function variable_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    # This is bounded for each time step by a fixed share (0 ≤ pshift_down_rel_max ≤ 1) of
    # the reference load demand pd for that time step. (Thus, while pshift_down_rel_max is a
    # scalar input parameter, the variable bounds become a time series.)
    pshift_down = _PM.var(pm, nw)[:pshift_down] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_pshift_down",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :load, i, "pd") * _PM.ref(pm, nw, :flex_load, i, "pshift_down_rel_max"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :pshift_down, _PM.ids(pm, nw, :flex_load), pshift_down)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :pshift_down, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end

"Variable for keeping track of the accumulated upward demand shifting over the operational planning horizon at each flex load point"
function variable_total_demand_shifting_downwards(pm::_PM.AbstractPowerModel; nw::Int=_PM.nw_id_default, bounded::Bool=true, report::Bool=true)
    first_nw = first_id(pm, nw, :hour)
    eshift_down = _PM.var(pm, nw)[:eshift_down] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :flex_load)], base_name="$(nw)_eshift_down",
        lower_bound = 0,
        upper_bound = _PM.ref(pm, nw, :flex_load, i, "eshift_rel_max") * _PM.ref(pm, first_nw, :flex_load, i, "ed"),
        start = 0
    )
    if report
        _PM.sol_component_value(pm, nw, :load, :eshift_down, _PM.ids(pm, nw, :flex_load), eshift_down)
        _IM.sol_component_fixed(pm, _PM.pm_it_sym, nw, :load, :eshift_down, _PM.ids(pm, nw, :fixed_load), 0.0)
    end
end



## Constraint templates

function constraint_flexible_demand_activation(pm::_PM.AbstractPowerModel, i::Int, prev_nws::Vector{Int}, nw::Int)
    investment_horizon = [nw]
    lifetime = _PM.ref(pm, nw, :load, i, "lifetime")
    for n in Iterators.reverse(prev_nws[max(end-lifetime+2,1):end])
        i in _PM.ids(pm, n, :load) ? push!(investment_horizon, n) : break
    end
    constraint_flexible_demand_activation(pm, nw, i, investment_horizon)
end

function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    load = _PM.ref(pm, nw, :load, i)
    constraint_flex_bounds_ne(pm, nw, i, load["pd"], load["pshift_up_rel_max"], load["pshift_down_rel_max"], load["pred_rel_max"])
end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    load     = _PM.ref(pm, nw, :load, i)
    pd       = load["pd"]
    pf_angle = get(load, "pf_angle", 0.0) # Power factor angle, in radians
    constraint_total_flexible_demand(pm, nw, i, pd, pf_angle)
end

function constraint_total_fixed_demand(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    load     = _PM.ref(pm, nw, :load, i)
    pd       = load["pd"]
    pf_angle = get(load, "pf_angle", 0.0) # Power factor angle, in radians
    constraint_total_fixed_demand(pm, nw, i, pd, pf_angle)
end

function constraint_red_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_red_state_initial(pm, nw, i, time_elapsed)
end

function constraint_red_state(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_red_state(pm, nw_1, nw_2, i, time_elapsed)
end

function constraint_shift_duration(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    constraint_shift_duration_up(pm, i, first_hour_nw, nw)
    constraint_shift_duration_down(pm, i, first_hour_nw, nw)
end

function constraint_shift_duration_up(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    load         = _PM.ref(pm, nw, :load, i)
    start_period = max(nw-load["tshift_up"], first_hour_nw)
    constraint_shift_duration_up(pm, nw, i, load["pd"], load["pshift_up_rel_max"], start_period)
end

function constraint_shift_duration_down(pm::_PM.AbstractPowerModel, i::Int, first_hour_nw::Int, nw::Int)
    load         = _PM.ref(pm, nw, :load, i)
    start_period = max(nw-load["tshift_down"], first_hour_nw)
    constraint_shift_duration_down(pm, nw, i, load["pd"], load["pshift_down_rel_max"], start_period)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
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

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
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

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, i::Int; nw::Int=_PM.nw_id_default)
    constraint_shift_state_final(pm, nw, i)
end

# This way of enforcing a balance between power shifted upward and power shifted downward:
# - does not use `eshift_up` and `eshift_down` variables;
# - is alternative to `constraint_shift_up_state`, `constraint_shift_down_state`, and
#   `constraint_shift_state_final`.
# It must be called only on last hour nws.
function constraint_shift_balance_periodic(pm::_PM.AbstractPowerModel, i::Int, period::Int; nw::Int=_PM.nw_id_default)
    timeseries_nw_ids = similar_ids(pm, nw, hour = 1:dim_length(pm,:hour))
    time_elapsed = Int(_PM.ref(pm, nw, :time_elapsed))
    if period % time_elapsed ≠ 0
        Memento.error(_LOGGER, "\"period\" must be a multiple of \"time_elapsed\".")
    end
    for horizon in Iterators.partition(timeseries_nw_ids, period÷time_elapsed)
        constraint_shift_balance_periodic(pm, horizon, i)
    end
end



## Constraint implementations

function constraint_flexible_demand_activation(pm::_PM.AbstractPowerModel, n::Int, i::Int, horizon::Vector{Int})
    indicator = _PM.var(pm, n, :z_flex, i)
    investments = _PM.var.(Ref(pm), horizon, :z_flex_investment, i)

    # Activate the flexibility depending on the investment decisions in the load's horizon.
    JuMP.@constraint(pm.model, indicator == sum(investments))
end

function constraint_flex_bounds_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int, pd, pshift_up_rel_max, pshift_down_rel_max, pred_rel_max)
    pshift_up   = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    pred        = _PM.var(pm, n, :pred, i)
    z           = _PM.var(pm, n, :z_flex, i)

    # Bounds on the demand flexibility decision variables (demand shifting and voluntary load reduction)
    JuMP.@constraint(pm.model, pshift_up   <=   pshift_up_rel_max * pd * z)
    JuMP.@constraint(pm.model, pshift_down <= pshift_down_rel_max * pd * z)
    JuMP.@constraint(pm.model, pred        <=        pred_rel_max * pd * z)
end

function constraint_total_flexible_demand(pm::_PM.AbstractPowerModel, n::Int, i, pd, pf_angle)
    pflex       = _PM.var(pm, n, :pflex, i)
    qflex       = _PM.var(pm, n, :qflex, i)
    pcurt       = _PM.var(pm, n, :pcurt, i)
    pred        = _PM.var(pm, n, :pred, i)
    pshift_up   = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)

    # Active power demand is the reference demand `pd` plus the contributions from all the demand flexibility decision variables
    JuMP.@constraint(pm.model, pflex == pd - pcurt - pred + pshift_up - pshift_down)

    # Reactive power demand is given by the active power demand and the power factor angle of the load
    JuMP.@constraint(pm.model, qflex == tan(pf_angle) * pflex)
end

function constraint_total_flexible_demand(pm::_PM.AbstractActivePowerModel, n::Int, i, pd, pf_angle)
    pflex       = _PM.var(pm, n, :pflex, i)
    pcurt       = _PM.var(pm, n, :pcurt, i)
    pred        = _PM.var(pm, n, :pred, i)
    pshift_up   = _PM.var(pm, n, :pshift_up, i)
    pshift_down = _PM.var(pm, n, :pshift_down, i)

    # Active power demand is the reference demand `pd` plus the contributions from all the demand flexibility decision variables
    JuMP.@constraint(pm.model, pflex == pd - pcurt - pred + pshift_up - pshift_down)
end

function constraint_total_fixed_demand(pm::_PM.AbstractPowerModel, n::Int, i, pd, pf_angle)
    pflex = _PM.var(pm, n, :pflex, i)
    qflex = _PM.var(pm, n, :qflex, i)
    pcurt = _PM.var(pm, n, :pcurt, i)

    # Active power demand is the difference between reference demand `pd` and involuntary curtailment
    JuMP.@constraint(pm.model, pflex == pd - pcurt)

    # Reactive power demand is given by the active power demand and the power factor angle of the load
    JuMP.@constraint(pm.model, qflex == tan(pf_angle) * pflex)
end

function constraint_total_fixed_demand(pm::_PM.AbstractActivePowerModel, n::Int, i, pd, pf_angle)
    pflex = _PM.var(pm, n, :pflex, i)
    pcurt = _PM.var(pm, n, :pcurt, i)

    # Active power demand is the difference between reference demand `pd` and involuntary curtailment
    JuMP.@constraint(pm.model, pflex == pd - pcurt)
end

function constraint_red_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pred = _PM.var(pm, n, :pred, i)
    ered = _PM.var(pm, n, :ered, i)

    # Initialization of not consumed energy variable (accumulated voluntary load reduction)
    JuMP.@constraint(pm.model, ered == time_elapsed * pred)
end

function constraint_red_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pred   = _PM.var(pm, n_2, :pred, i)
    ered_2 = _PM.var(pm, n_2, :ered, i)
    ered_1 = _PM.var(pm, n_1, :ered, i)

    # Accumulation of not consumed energy (accumulation of voluntary load reduction for each time step)
    JuMP.@constraint(pm.model, ered_2 - ered_1 == time_elapsed * pred)
end

function constraint_shift_duration_up(pm::_PM.AbstractPowerModel, n::Int, i::Int, pd, pshift_up_rel_max, start_period::Int)
    # Apply an upper bound to the demand shifted upward during the recovery period
    JuMP.@constraint(pm.model, sum(_PM.var(pm, t, :pshift_up, i) for t in start_period:n) <= pshift_up_rel_max * pd)
end

function constraint_shift_duration_down(pm::_PM.AbstractPowerModel, n::Int, i::Int, pd, pshift_down_rel_max, start_period::Int)
    # Apply an upper bound to the demand shifted downward during the recovery period
    JuMP.@constraint(pm.model, sum(_PM.var(pm, t, :pshift_down, i) for t in start_period:n) <= pshift_down_rel_max * pd)
end

function constraint_shift_up_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pshift_up = _PM.var(pm, n, :pshift_up, i)
    eshift_up = _PM.var(pm, n, :eshift_up, i)

    # Initialization of accumulated upward demand shifting variable
    JuMP.@constraint(pm.model, eshift_up == time_elapsed * pshift_up)
end

function constraint_shift_up_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pshift_up   = _PM.var(pm, n_2, :pshift_up, i)
    eshift_up_2 = _PM.var(pm, n_2, :eshift_up, i)
    eshift_up_1 = _PM.var(pm, n_1, :eshift_up, i)

    # Accumulation of upward demand shifting for each time step
    JuMP.@constraint(pm.model, eshift_up_2 - eshift_up_1 == time_elapsed * pshift_up)
end

function constraint_shift_down_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    pshift_down = _PM.var(pm, n, :pshift_down, i)
    eshift_down = _PM.var(pm, n, :eshift_down, i)

    # Initialization of accumulated downward demand shifting variable
    JuMP.@constraint(pm.model, eshift_down == time_elapsed * pshift_down)
end

function constraint_shift_down_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    pshift_down   = _PM.var(pm, n_2, :pshift_down, i)
    eshift_down_2 = _PM.var(pm, n_2, :eshift_down, i)
    eshift_down_1 = _PM.var(pm, n_1, :eshift_down, i)

    # Accumulation of downward demand shifting for each time step
    JuMP.@constraint(pm.model, eshift_down_2 - eshift_down_1 == time_elapsed * pshift_down)
end

function constraint_shift_state_final(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    eshift_up   = _PM.var(pm, n, :eshift_up, i)
    eshift_down = _PM.var(pm, n, :eshift_down, i)

    # The accumulated upward demand shifting over the operational planning horizon should equal the accumulated downward
    # demand shifting (since this is demand shifted and not reduced or curtailed)
    JuMP.@constraint(pm.model, eshift_up == eshift_down)
end

function constraint_shift_balance_periodic(pm::_PM.AbstractPowerModel, horizon::AbstractVector{Int}, i::Int)
    pshift_up   = _PM.var.(Ref(pm), horizon, :pshift_up, i)
    pshift_down = _PM.var.(Ref(pm), horizon, :pshift_down, i)

    JuMP.@constraint(pm.model, sum(pshift_up) == sum(pshift_down))
end
