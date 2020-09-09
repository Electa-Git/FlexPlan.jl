export flex_tnep

""
function flex_tnep(data::Dict{String,Any}, model_type::Type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
    s = setting
    return _PM.run_model(data, model_type, solver, post_flex_tnep; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
end

""
function post_flex_tnep(pm::_PM.AbstractPowerModel)
    for (n, networks) in pm.ref[:nw]
        _PM.variable_bus_voltage(pm; nw = n)
        _PM.variable_gen_power(pm; nw = n)
        _PM.variable_branch_power(pm; nw = n)
        _PM.variable_storage_power(pm; nw = n)

        _PMACDC.variable_voltage_slack(pm; nw = n)
        _PMACDC.variable_active_dcbranch_flow(pm; nw = n)
        _PMACDC.variable_dc_converter(pm; nw = n)
        _PMACDC.variable_dcbranch_current(pm; nw = n)
        _PMACDC.variable_dcgrid_voltage_magnitude(pm; nw = n)
        variable_absorbed_energy(pm; nw = n)
        variable_absorbed_energy_ne(pm; nw = n)
        variable_flexible_demand(pm; nw = n)


        # new variables for TNEP problem
        _PM.variable_ne_branch_indicator(pm; nw = n)
        _PM.variable_ne_branch_power(pm; nw = n)
        _PM.variable_ne_branch_voltage(pm; nw = n)
        variable_storage_power_ne(pm; nw = n)
        _PMACDC.variable_active_dcbranch_flow_ne(pm; nw = n)
        _PMACDC.variable_branch_ne(pm; nw = n)
        _PMACDC.variable_dc_converter_ne(pm; nw = n)
        _PMACDC.variable_dcbranch_current_ne(pm; nw = n)
        _PMACDC.variable_dcgrid_voltage_magnitude_ne(pm; nw = n)
    end
    objective_min_cost_flex(pm)
    for (n, networks) in pm.ref[:nw]
        _PM.constraint_model_voltage(pm; nw = n)
        _PM.constraint_ne_model_voltage(pm; nw = n)
        _PMACDC.constraint_voltage_dc(pm; nw = n)
        _PMACDC.constraint_voltage_dc_ne(pm; nw = n)
        for i in _PM.ids(pm, n, :ref_buses)
            _PM.constraint_theta_ref(pm, i, nw = n)
        end

        for i in _PM.ids(pm, n, :bus)
            constraint_power_balance_acne_dcne_flex(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :branch)
            _PM.constraint_ohms_yt_from(pm, i; nw = n)
            _PM.constraint_ohms_yt_to(pm, i; nw = n)
            _PM.constraint_voltage_angle_difference(pm, i; nw = n)
            _PM.constraint_thermal_limit_from(pm, i; nw = n)
            _PM.constraint_thermal_limit_to(pm, i; nw = n)
        end
        for i in _PM.ids(pm, n, :ne_branch)
            _PM.constraint_ne_ohms_yt_from(pm, i; nw = n)
            _PM.constraint_ne_ohms_yt_to(pm, i; nw = n)
            _PM.constraint_ne_voltage_angle_difference(pm, i; nw = n)
            _PM.constraint_ne_thermal_limit_from(pm, i; nw = n)
            _PM.constraint_ne_thermal_limit_to(pm, i; nw = n)
            if n > 1
                _PMACDC.constraint_candidate_acbranches_mp(pm, n, i)
            end
        end

        for i in _PM.ids(pm, n, :busdc)
            _PMACDC.constraint_power_balance_dc_dcne(pm, i; nw = n)
        end
        for i in _PM.ids(pm, n, :busdc_ne)
            _PMACDC.constraint_power_balance_dcne_dcne(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :branchdc)
            _PMACDC.onstraint_ohms_dc_branch(pm, i; nw = n)
        end
        for i in _PM.ids(pm, :branchdc_ne)
            _PMACDC.constraint_ohms_dc_branch_ne(pm, i; nw = n)
            _PMACDC.constraint_branch_limit_on_off(pm, i; nw = n)
            if n > 1
                _PMACDC.constraint_candidate_dcbranches_mp(pm, n, i)
            end
        end

        for i in _PM.ids(pm, :convdc)
            _PMACDC.constraint_converter_losses(pm, i; nw = n)
            _PMACDC.constraint_converter_current(pm, i; nw = n)
            _PMACDC.constraint_conv_transformer(pm, i; nw = n)
            _PMACDC.constraint_conv_reactor(pm, i; nw = n)
            _PMACDC.constraint_conv_filter(pm, i; nw = n)
            if pm.ref[:nw][n][:convdc][i]["islcc"] == 1
                _PMACDC.constraint_conv_firing_angle(pm, i; nw = n)
            end
        end
        for i in _PM.ids(pm, n, :convdc_ne)
            _PMACDC.constraint_converter_losses_ne(pm, i; nw = n)
            _PMACDC.constraint_converter_current_ne(pm, i; nw = n)
            _PMACDC.constraint_converter_limit_on_off(pm, i; nw = n)
            if n > 1
                _PMACDC.constraint_candidate_converters_mp(pm, n, i)
            end
            _PMACDC.constraint_conv_transformer_ne(pm, i; nw = n)
            _PMACDC.constraint_conv_reactor_ne(pm, i; nw = n)
            _PMACDC.constraint_conv_filter_ne(pm, i; nw = n)
            if pm.ref[:nw][n][:convdc_ne][i]["islcc"] == 1
                _PMACDC.constraint_conv_firing_angle_ne(pm, i; nw = n)
            end
        end

        for i in _PM.ids(pm, :load, nw = n)
            if _PM.ref(pm, n, :load, i, "flex") == 0
                constraint_fixed_demand(pm, i; nw = n)
            else
                constraint_flex_bounds_ne(pm, i; nw = n)
            end
            constraint_total_flexible_demand(pm, i; nw = n)
        end

        for i in _PM.ids(pm, :storage, nw=n)
            constraint_storage_excl_slack(pm, i, nw = n)
            _PM.constraint_storage_thermal_limit(pm, i, nw = n)
            _PM.constraint_storage_losses(pm, i, nw = n)
        end
        for i in _PM.ids(pm, :ne_storage, nw=n)
            constraint_storage_excl_slack_ne(pm, i, nw = n)
            constraint_storage_thermal_limit_ne(pm, i, nw = n)
            constraint_storage_losses_ne(pm, i, nw = n)
            constraint_storage_bounds_ne(pm, i, nw = n)
        end
    end
    network_ids = sort(collect(_PM.nw_ids(pm)))
    n_1 = network_ids[1]
    n_last = network_ids[end]
    # NW = 1
    for i in _PM.ids(pm, :storage, nw = n_1)
        constraint_storage_state(pm, i, nw = n_1)
        constraint_maximum_absorption(pm, i, nw = n_1)
    end

    for i in _PM.ids(pm, :ne_storage, nw = n_1)
        constraint_storage_state_ne(pm, i, nw = n_1)
        constraint_maximum_absorption_ne(pm, i, nw = n_1)
    end

    for i in _PM.ids(pm, :load, nw = n_1)
        if _PM.ref(pm, n_1, :load, i, "flex") == 1
            constraint_ence_state(pm, i, nw = n_1)
            constraint_shift_up_state(pm, i, nw = n_1)
            constraint_shift_down_state(pm, i, nw = n_1)
        end
    end
    # NW = last
    for i in _PM.ids(pm, :storage, nw = n_last)
        constraint_storage_state_final(pm, i, nw = n_last)
    end

    for i in _PM.ids(pm, :ne_storage, nw = n_last)
        constraint_storage_state_final_ne(pm, i, nw = n_last)
    end

    for i in _PM.ids(pm, :load, nw = n_last)
        if _PM.ref(pm, n_last, :load, i, "flex") == 1
            constraint_shift_state_final(pm, i, nw = n_last)
        end
    end

    # NW = 2......last
    for n_2 in network_ids[2:end]
        for i in _PM.ids(pm, :storage, nw = n_2)
            constraint_storage_state(pm, i, n_1, n_2)
            constraint_maximum_absorption(pm, i, n_1, n_2)
        end
        for i in _PM.ids(pm, :ne_storage, nw = n_2)
            constraint_storage_state_ne(pm, i, n_1, n_2)
            constraint_maximum_absorption_ne(pm, i, n_1, n_2)
            constraint_storage_investment(pm, n_1, n_2, i)
        end
        for i in _PM.ids(pm, :load, nw = n_2)
            if _PM.ref(pm, n_2, :load, i, "flex") == 1
                constraint_ence_state(pm, i, n_1, n_2)
                constraint_shift_up_state(pm, n_1, n_2, i)
                constraint_shift_down_state(pm, n_1, n_2, i)
                constraint_shift_duration(pm, n_2, network_ids, i)
                constraint_flex_investment(pm, n_1, n_2, i)
            end
        end
        n_1 = n_2
    end

end
#################################################################
##################### Objective
##################################################################
 function objective_min_cost_flex(pm::_PM.AbstractPowerModel)
         gen_cost = Dict()
         for (n, nw_ref) in _PM.nws(pm)
             for (i,gen) in nw_ref[:gen]
                 pg = _PM.var(pm, n, :pg, i)

                 if length(gen["cost"]) == 1
                     gen_cost[(n,i)] = gen["cost"][1]
                 elseif length(gen["cost"]) == 2
                     gen_cost[(n,i)] = gen["cost"][1]*pg + gen["cost"][2]
                 elseif length(gen["cost"]) == 3
                     gen_cost[(n,i)] = gen["cost"][2]*pg + gen["cost"][3]
                 else
                     gen_cost[(n,i)] = 0.0
                 end
             end
         end

         return JuMP.@objective(pm.model, Min,
             sum(
                 sum(conv["cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in nw_ref[:convdc_ne])
                 +
                 sum(branch["construction_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in nw_ref[:ne_branch])
                 +
                 sum(branch["cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in nw_ref[:branchdc_ne])
                 +
                 sum((storage["eq_cost"] + storage["inst_cost"] + storage["env_cost"])*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in nw_ref[:ne_storage])
                 +
                 sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
                 +
                 sum(load["cost_shift_up"]*_PM.var(pm, n, :pshift_up, i) for (i,load) in nw_ref[:load])
                 +
                 sum(load["cost_shift_down"]*_PM.var(pm, n, :pshift_down, i) for (i,load) in nw_ref[:load])
                 +
                 sum(load["cost_reduction"]*_PM.var(pm, n, :pnce, i) for (i,load) in nw_ref[:load])
                 +
                 sum(load["cost_curtailment"]*_PM.var(pm, n, :pcurt, i) for (i,load) in nw_ref[:load])
                 +
                 sum(load["cost_investment"]*_PM.var(pm, n, :z_flex, i) for (i,load) in nw_ref[:load])
                 for (n, nw_ref) in _PM.nws(pm)
                     )
         )
 end

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
# ############### Constraint Templates
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
function constraint_power_balance_acne_dcne_flex(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    bus = PowerModels.ref(pm, nw, :bus, i)
    bus_arcs = PowerModels.ref(pm, nw, :bus_arcs, i)
    bus_arcs_ne = PowerModels.ref(pm, nw, :ne_bus_arcs, i)
    bus_arcs_dc = PowerModels.ref(pm, nw, :bus_arcs_dc, i)
    bus_gens = PowerModels.ref(pm, nw, :bus_gens, i)
    bus_convs_ac = PowerModels.ref(pm, nw, :bus_convs_ac, i)
    bus_convs_ac_ne = PowerModels.ref(pm, nw, :bus_convs_ac_ne, i)
    bus_loads = PowerModels.ref(pm, nw, :bus_loads, i)
    bus_shunts = PowerModels.ref(pm, nw, :bus_shunts, i)
    bus_storage = PowerModels.ref(pm, nw, :bus_storage, i)
    bus_storage_ne = PowerModels.ref(pm, nw, :bus_storage_ne, i)

    pd = Dict(k => PowerModels.ref(pm, nw, :load, k, "pd") for k in bus_loads)
    qd = Dict(k => PowerModels.ref(pm, nw, :load, k, "qd") for k in bus_loads)

    gs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "gs") for k in bus_shunts)
    bs = Dict(k => PowerModels.ref(pm, nw, :shunt, k, "bs") for k in bus_shunts)
    constraint_power_balance_acne_dcne_flex(pm, nw, i, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
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

function constraint_power_balance_acne_dcne_flex(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne = _PM.var(pm, n, :pconv_ac_ne)
    p_ne = _PM.var(pm, n, :p_ne)
    ps   = _PM.var(pm, n, :ps)
    ps_ne   = _PM.var(pm, n, :ps_ne)
    pflex = _PM.var(pm, n, :pflex)
    v = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pflex[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
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
    # JuMP.@constraint(pm.model, pshift_up <= pshift_up_max - sum(_PM.var(pm, n, :pshift_up_tot, i) for n in n_idx[n_2 - t_grace:n_2-1]))
    JuMP.@constraint(pm.model, pshift_up <= pshift_up_max - _PM.var(pm, t, :pshift_up_tot, i))
end

function constraint_shift_duration_down(pm, n_2, n_idx, i, t_grace)
    pshift_down = _PM.var(pm, n_2, :pshift_down, i)
    pshift_down_max = JuMP.upper_bound(pshift_down)
    t = max(1, n_2 - t_grace)
    # JuMP.@constraint(pm.model, pshift_down <= pshift_down_max - sum(_PM.var(pm, n, :pshift_down_tot, i) for n in n_idx[n_2 - t_grace:n_2-1]))
    JuMP.@constraint(pm.model, pshift_down <= pshift_down_max - _PM.var(pm, t, :pshift_down_tot, i))
end
