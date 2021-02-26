##################################################################################
#### DEFINTION OF NEW VARIABLES FOR STORAGE INVESTMENTS ACCODING TO FlexPlan MODEL
##################################################################################
function variable_absorbed_energy(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool = true, report::Bool=true)
    e_abs = _PM.var(pm, nw)[:e_abs] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :storage)], base_name="$(nw)_e_abs",
    start = 0)

    if bounded
        for (s, storage) in _PM.ref(pm, nw, :storage)
            JuMP.set_lower_bound(e_abs[s],  0)
            JuMP.set_upper_bound(e_abs[s],  storage["max_energy_absorption"])
        end
    end

    report && _IM.sol_component_value(pm, nw, :storage, :e_abs, _PM.ids(pm, nw, :storage), e_abs)
end

function variable_absorbed_energy_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool = true, report::Bool=true)
    e_abs = _PM.var(pm, nw)[:e_abs_ne] = JuMP.@variable(pm.model,
    [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_e_abs_ne",
    start = 0)

    if bounded
        for (s, storage) in _PM.ref(pm, nw, :ne_storage)
            JuMP.set_lower_bound(e_abs[s],  0)
            JuMP.set_upper_bound(e_abs[s],  storage["max_energy_absorption"])
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :e_abs_ne, _PM.ids(pm, nw, :ne_storage), e_abs)
end


function variable_storage_power_ne(pm::_PM.AbstractPowerModel; kwargs...)
    variable_storage_power_real_ne(pm; kwargs...)
    variable_storage_power_imaginary_ne(pm; kwargs...)
    variable_storage_power_control_imaginary_ne(pm; kwargs...)
    variable_storage_current_ne(pm; kwargs...)
    variable_storage_energy_ne(pm; kwargs...)
    variable_storage_charge_ne(pm; kwargs...)
    variable_storage_discharge_ne(pm; kwargs...)
    variable_storage_investment(pm; kwargs...)
end

function variable_storage_power_real_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    ps = _PM.var(pm, nw)[:ps_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_ps_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "ps_start")
    )

    if bounded
        inj_lb, inj_ub = _PM.ref_calc_storage_injection_bounds(_PM.ref(pm, nw, :ne_storage), _PM.ref(pm, nw, :bus))

        for i in _PM.ids(pm, nw, :ne_storage)
            if !isinf(inj_lb[i])
                JuMP.set_lower_bound(ps[i], inj_lb[i])
            end
            if !isinf(inj_ub[i])
                JuMP.set_upper_bound(ps[i], inj_ub[i])
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :ps_ne, _PM.ids(pm, nw, :ne_storage), ps)
end

function variable_storage_power_imaginary_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    qs = _PM.var(pm, nw)[:qs_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_qs_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "qs_start")
    )

    if bounded
        inj_lb, inj_ub = _PM.ref_calc_storage_injection_bounds(_PM.ref(pm, nw, :ne_storage), _PM.ref(pm, nw, :bus))

        for (i, storage) in _PM.ref(pm, nw, :ne_storage)
            JuMP.set_lower_bound(qs[i], max(inj_lb[i], storage["qmin"]))
            JuMP.set_upper_bound(qs[i], min(inj_ub[i], storage["qmax"]))
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :qs_ne, _PM.ids(pm, nw, :ne_storage), qs)
end

"apo models ignore reactive power flows"
function variable_storage_power_imaginary_ne(pm::_PM.AbstractActivePowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    report && _IM.sol_component_fixed(pm, nw, :ne_storage, :qs_ne, _PM.ids(pm, nw, :ne_storage), NaN)
end

function variable_storage_power_control_imaginary_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    qsc = _PM.var(pm, nw)[:qsc_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_qsc_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "qsc_start")
    )

    if bounded
        inj_lb, inj_ub = _PM.ref_calc_storage_injection_bounds(_PM.ref(pm, nw, :ne_storage), _PM.ref(pm, nw, :bus))

        for (i,storage) in _PM.ref(pm, nw, :ne_storage)

            if !isinf(inj_lb[i]) || haskey(storage, "qmin")
                JuMP.set_lower_bound(qsc[i], max(inj_lb[i], get(storage, "qmin", -Inf)))
            end
            if !isinf(inj_ub[i]) || haskey(storage, "qmax")
                JuMP.set_upper_bound(qsc[i], min(inj_ub[i], get(storage, "qmax",  Inf)))
            end
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :qsc_ne, _PM.ids(pm, nw, :ne_storage), qsc)
end

"apo models ignore reactive power flows"
function variable_storage_power_control_imaginary_ne(pm::_PM.AbstractActivePowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    report && _IM.sol_component_fixed(pm, nw, :ne_storage, :qsc_ne, _PM.ids(pm, nw, :ne_storage), NaN)
end

"do nothing by default but some formulations require this"
function variable_storage_current_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
end

function variable_storage_energy_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    se = _PM.var(pm, nw)[:se_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_se_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "se_start", 1)
    )

    if bounded
        for (i, storage) in _PM.ref(pm, nw, :ne_storage)
            JuMP.set_lower_bound(se[i], 0)
            JuMP.set_upper_bound(se[i], storage["energy_rating"])
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :se_ne, _PM.ids(pm, nw, :ne_storage), se)
end

function variable_storage_charge_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    sc = _PM.var(pm, nw)[:sc_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_sc_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "sc_start", 1)
    )

    if bounded
        for (i, storage) in _PM.ref(pm, nw, :ne_storage)
            JuMP.set_lower_bound(sc[i], 0)
            JuMP.set_upper_bound(sc[i], storage["charge_rating"])
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :sc_ne, _PM.ids(pm, nw, :ne_storage), sc)
end

function variable_storage_discharge_ne(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, bounded::Bool=true, report::Bool=true)
    sd = _PM.var(pm, nw)[:sd_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_sd_ne",
        start = _PM.comp_start_value(_PM.ref(pm, nw, :ne_storage, i), "sd_start", 1)
    )

    if bounded
        for (i, storage) in _PM.ref(pm, nw, :ne_storage)
            JuMP.set_lower_bound(sd[i], 0)
            JuMP.set_upper_bound(sd[i], storage["discharge_rating"])
        end
    end

    report && _IM.sol_component_value(pm, nw, :ne_storage, :sd_ne, _PM.ids(pm, nw, :ne_storage), sd)
end

function variable_storage_investment(pm::_PM.AbstractPowerModel; nw::Int=pm.cnw, relax::Bool=false, report::Bool=true)
    if !relax
        z = _PM.var(pm, nw)[:z_strg_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_z_strg_ne",
        binary = true,
        start = 0
        )
    else
        z = _PM.var(pm, nw)[:z_strg_ne] = JuMP.@variable(pm.model,
        [i in _PM.ids(pm, nw, :ne_storage)], base_name="$(nw)_z_strg_ne",
        lower_bound = 0,
        upper_bound = 1,
        start = 0
        )
    end
    report && _IM.sol_component_value(pm, nw, :ne_storage, :isbuilt, _PM.ids(pm, nw, :ne_storage), z)
 end

# ####################################################
# Constraint Templates: They are used to do all data manipuations and return a function with the same name,
# this way the constraint itself only containts the mathematical formulation
# ###################################################
function constraint_storage_thermal_limit_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)
    constraint_storage_thermal_limit_ne(pm, nw, i, storage["thermal_rating"])
end

function constraint_storage_losses_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)

    constraint_storage_losses_ne(pm, nw, i, storage["storage_bus"], storage["r"], storage["x"], storage["p_loss"], storage["q_loss"])
end

function constraint_storage_bounds_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_storage_bounds_ne(pm, nw, i)
end


function constraint_storage_state(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :storage, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_storage_state_initial(pm, nw, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
end

function constraint_storage_state_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_storage_state_initial_ne(pm, nw, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
end

function constraint_storage_state(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    storage = _PM.ref(pm, nw_2, :storage, i)

    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    if haskey(_PM.ref(pm, nw_1, :storage), i)
        constraint_storage_state(pm, nw_1, nw_2, i, storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_storage_state_initial(pm, nw_2, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
    end
end

function constraint_storage_state_ne(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    storage = _PM.ref(pm, nw_2, :ne_storage, i)

    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    if haskey(_PM.ref(pm, nw_1, :ne_storage), i)
        constraint_storage_state_ne(pm, nw_1, nw_2, i, storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_storage_state_initial_ne(pm, nw_2, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], storage["self_discharge_rate"], time_elapsed)
    end
end

function constraint_storage_state_final(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :storage, i)
    constraint_storage_state_final(pm, nw, i, storage["energy"])
end

function constraint_storage_state_final_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)
    constraint_storage_state_final_ne(pm, nw, i, storage["energy"])
end

function constraint_storage_excl_slack(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_storage_excl_slack(pm, nw, i)
end

function constraint_storage_excl_slack_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    constraint_storage_excl_slack_ne(pm, nw, i)
end

function constraint_maximum_absorption(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :storage, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_maximum_absorption_initial(pm, nw, i, time_elapsed)
end

function constraint_maximum_absorption_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_maximum_absorption_initial_ne(pm, nw, i, time_elapsed)
end

function  constraint_maximum_absorption(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    storage = _PM.ref(pm, nw_2, :storage, i)

    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    if haskey(_PM.ref(pm, nw_1, :storage), i)
        constraint_maximum_absorption(pm, nw_1, nw_2, i, time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_maximum_absorption_initial(pm, nw_2, i, time_elapsed)
    end
end

function  constraint_maximum_absorption_ne(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
    storage = _PM.ref(pm, nw_2, :ne_storage, i)

    if haskey(_PM.ref(pm, nw_2), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw_2, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network $(nw_2) should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end

    if haskey(_PM.ref(pm, nw_1, :ne_storage), i)
        constraint_maximum_absorption_ne(pm, nw_1, nw_2, i, time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_maximum_absorption_initial_ne(pm, nw_2, i, time_elapsed)
    end
end


####################################################
############### Constraints
###################################################

function _PM.constraint_storage_thermal_limit(pm::BFARadPowerModel, n::Int, i, rating)
    ps = _PM.var(pm, n, :ps, i)
    qs = _PM.var(pm, n, :qs, i)

    c_perp = cos(π/8) # ~0.92
    c_diag = sin(π/8) + cos(π/8) # == cos(π/8) * sqrt(2), ~1.31

    JuMP.@constraint(pm.model, -c_perp*rating <= ps      <= c_perp*rating)
    JuMP.@constraint(pm.model, -c_perp*rating <=      qs <= c_perp*rating)
    JuMP.@constraint(pm.model, -c_diag*rating <= ps + qs <= c_diag*rating)
    JuMP.@constraint(pm.model, -c_diag*rating <= ps - qs <= c_diag*rating)
end

function constraint_storage_thermal_limit_ne(pm::_PM.AbstractActivePowerModel, n::Int, i, rating)
    ps = _PM.var(pm, n, :ps_ne, i)

    JuMP.lower_bound(ps) < -rating && JuMP.set_lower_bound(ps, -rating)
    JuMP.upper_bound(ps) >  rating && JuMP.set_upper_bound(ps,  rating)
end

function constraint_storage_thermal_limit_ne(pm::BFARadPowerModel, n::Int, i, rating)
    ps = _PM.var(pm, n, :ps_ne, i)
    qs = _PM.var(pm, n, :qs_ne, i)

    c_perp = cos(π/8) # ~0.92
    c_diag = sin(π/8) + cos(π/8) # == cos(π/8) * sqrt(2), ~1.31

    JuMP.@constraint(pm.model, -c_perp*rating <= ps      <= c_perp*rating)
    JuMP.@constraint(pm.model, -c_perp*rating <=      qs <= c_perp*rating)
    JuMP.@constraint(pm.model, -c_diag*rating <= ps + qs <= c_diag*rating)
    JuMP.@constraint(pm.model, -c_diag*rating <= ps - qs <= c_diag*rating)
end

function constraint_storage_losses_ne(pm::_PM.AbstractAPLossLessModels, n::Int, i, bus, r, x, p_loss, q_loss)
    ps = _PM.var(pm, n, :ps_ne, i)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)

    JuMP.@constraint(pm.model, ps + (sd - sc) == p_loss)
end

"Neglects the active and reactive loss terms associated with the squared current magnitude."
function constraint_storage_losses_ne(pm::_PM.AbstractBFAModel, n::Int, i, bus, r, x, p_loss, q_loss)
    ps  = _PM.var(pm, n, :ps_ne, i)
    qs  = _PM.var(pm, n, :qs_ne, i)
    sc  = _PM.var(pm, n, :sc_ne, i)
    sd  = _PM.var(pm, n, :sd_ne, i)
    qsc = _PM.var(pm, n, :qsc_ne, i)

    JuMP.@constraint(pm.model, ps + (sd - sc) == p_loss)
    JuMP.@constraint(pm.model, qs == qsc + q_loss)
end

function constraint_storage_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, inflow, outflow, self_discharge_rate, time_elapsed)
    sc = _PM.var(pm, n, :sc, i)
    sd = _PM.var(pm, n, :sd, i)
    se = _PM.var(pm, n, :se, i)

    JuMP.@constraint(pm.model, se == ((1-self_discharge_rate)^time_elapsed)*energy + time_elapsed*(charge_eff*sc - sd/discharge_eff + inflow - outflow))
end

function constraint_storage_state_initial_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, inflow, outflow, self_discharge_rate, time_elapsed)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)
    se = _PM.var(pm, n, :se_ne, i)
    z = _PM.var(pm, n, :z_strg_ne, i)

    JuMP.@constraint(pm.model, se == ((1-self_discharge_rate)^time_elapsed)*energy + time_elapsed*(charge_eff*sc - sd/discharge_eff + inflow * z - outflow * z))
end

function constraint_storage_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, inflow, outflow, self_discharge_rate, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc, i)
    sd_2 = _PM.var(pm, n_2, :sd, i)
    se_2 = _PM.var(pm, n_2, :se, i)
    se_1 = _PM.var(pm, n_1, :se, i)

    JuMP.@constraint(pm.model, se_2 == ((1-self_discharge_rate)^time_elapsed)*se_1 + time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff + inflow - outflow))
end

function constraint_storage_state_ne(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, inflow, outflow, self_discharge_rate, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc_ne, i)
    sd_2 = _PM.var(pm, n_2, :sd_ne, i)
    se_2 = _PM.var(pm, n_2, :se_ne, i)
    se_1 = _PM.var(pm, n_1, :se_ne, i)
    z = _PM.var(pm, n_2, :z_strg_ne, i)

    JuMP.@constraint(pm.model, se_2 == ((1-self_discharge_rate)^time_elapsed)*se_1 + time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff + inflow * z - outflow * z))
end

function constraint_storage_state_final(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy)
    se = _PM.var(pm, n, :se, i)

    JuMP.@constraint(pm.model, se >= energy)
end

function constraint_storage_state_final_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy)
    se = _PM.var(pm, n, :se_ne, i)

    JuMP.@constraint(pm.model, se >= energy)
end

function constraint_maximum_absorption_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    sc = _PM.var(pm, n, :sc, i)
    e_abs = _PM.var(pm, n, :e_abs, i)

    JuMP.@constraint(pm.model, e_abs == time_elapsed * sc)
end

function constraint_maximum_absorption_initial_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int, time_elapsed)
    sc = _PM.var(pm, n, :sc_ne, i)
    e_abs = _PM.var(pm, n, :e_abs_ne, i)

    JuMP.@constraint(pm.model, e_abs == time_elapsed * sc)
end

function constraint_maximum_absorption(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc, i)
    e_abs_2 = _PM.var(pm, n_2, :e_abs, i)
    e_abs_1 = _PM.var(pm, n_1, :e_abs, i)

    JuMP.@constraint(pm.model, e_abs_2 - e_abs_1 == time_elapsed * sc_2)
end

function constraint_maximum_absorption_ne(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc_ne, i)
    e_abs_2 = _PM.var(pm, n_2, :e_abs_ne, i)
    e_abs_1 = _PM.var(pm, n_1, :e_abs_ne, i)

    JuMP.@constraint(pm.model, e_abs_2 - e_abs_1 == time_elapsed * sc_2)
end

function constraint_storage_excl_slack(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    sc = _PM.var(pm, n, :sc, i)
    sd = _PM.var(pm, n, :sd, i)
    sc_max = JuMP.upper_bound(sc)
    sd_max = JuMP.upper_bound(sd)
    s_bound = max(sc_max, sd_max)

    JuMP.@constraint(pm.model, sc + sd <= s_bound)
end

function constraint_storage_excl_slack_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)
    sc_max = JuMP.upper_bound(sc)
    sd_max = JuMP.upper_bound(sd)
    s_bound = max(sc_max, sd_max)

    JuMP.@constraint(pm.model, sc + sd <= s_bound)
end


function constraint_storage_bounds_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int)
    se = _PM.var(pm, n, :se_ne, i)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)
    ps = _PM.var(pm, n, :ps_ne, i)
    qs = _PM.var(pm, n, :qs_ne, i)
    z = _PM.var(pm, n, :z_strg_ne, i)

    se_min = JuMP.lower_bound(se)
    se_max = JuMP.upper_bound(se)
    sc_min = JuMP.lower_bound(sc)
    sc_max = JuMP.upper_bound(sc)
    sd_min = JuMP.lower_bound(sd)
    sd_max = JuMP.upper_bound(sd)
    ps_min = JuMP.lower_bound(ps)
    ps_max = JuMP.upper_bound(ps)
    qs_min = JuMP.lower_bound(qs)
    qs_max = JuMP.upper_bound(qs)

    JuMP.@constraint(pm.model, se  <= se_max * z)
    JuMP.@constraint(pm.model, se  >= se_min * z)
    JuMP.@constraint(pm.model, sc  <= sc_max * z)
    JuMP.@constraint(pm.model, sc  >= sc_min * z)
    JuMP.@constraint(pm.model, sd  <= sd_max * z)
    JuMP.@constraint(pm.model, sd  >= sd_min * z)
    JuMP.@constraint(pm.model, ps  <= ps_max * z)
    JuMP.@constraint(pm.model, ps  >= ps_min * z)
    JuMP.@constraint(pm.model, qs  <= qs_max * z)
    JuMP.@constraint(pm.model, qs  >= qs_min * z)
end

function constraint_storage_bounds_ne(pm::_PM.AbstractActivePowerModel, n::Int, i::Int)
    se = _PM.var(pm, n, :se_ne, i)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)
    ps = _PM.var(pm, n, :ps_ne, i)
    z = _PM.var(pm, n, :z_strg_ne, i)

    se_min = JuMP.lower_bound(se)
    se_max = JuMP.upper_bound(se)
    sc_min = JuMP.lower_bound(sc)
    sc_max = JuMP.upper_bound(sc)
    sd_min = JuMP.lower_bound(sd)
    sd_max = JuMP.upper_bound(sd)
    ps_min = JuMP.lower_bound(ps)
    ps_max = JuMP.upper_bound(ps)

    JuMP.@constraint(pm.model, se  <= se_max * z)
    JuMP.@constraint(pm.model, se  >= se_min * z)
    JuMP.@constraint(pm.model, sc  <= sc_max * z)
    JuMP.@constraint(pm.model, sc  >= sc_min * z)
    JuMP.@constraint(pm.model, sd  <= sd_max * z)
    JuMP.@constraint(pm.model, sd  >= sd_min * z)
    JuMP.@constraint(pm.model, ps  <= ps_max * z)
    JuMP.@constraint(pm.model, ps  >= ps_min * z)
end

function constraint_storage_investment(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int)
    z_1 = _PM.var(pm, n_1, :z_strg_ne, i)
    z_2 = _PM.var(pm, n_2, :z_strg_ne, i)

    JuMP.@constraint(pm.model, z_1 == z_2)
end
