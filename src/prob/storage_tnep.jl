export strg_tnep

""
function strg_tnep(data::Dict{String,Any}, model_type::Type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
    # if setting["process_data_internally"] == true
    #     process_additional_data!(data)
    # end
    s = setting
    return _PM.run_model(data, model_type, solver, post_strg_tnep; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
end

""
function post_strg_tnep(pm::_PM.AbstractPowerModel)
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
    objective_min_cost_storage(pm)
    for (n, networks) in pm.ref[:nw]
        _PM.constraint_model_voltage(pm; nw = n)
        _PM.constraint_ne_model_voltage(pm; nw = n)
        _PMACDC.constraint_voltage_dc(pm; nw = n)
        _PMACDC.constraint_voltage_dc_ne(pm; nw = n)
        for i in _PM.ids(pm, n, :ref_buses)
            _PM.constraint_theta_ref(pm, i, nw = n)
        end

        for i in _PM.ids(pm, n, :bus)
            constraint_power_balance_acne_dcne_strg(pm, i; nw = n)
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
            _PMACDC.constraint_ohms_dc_branch(pm, i; nw = n)
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
    for i in _PM.ids(pm, :storage, nw = n_1)
        constraint_storage_state(pm, i, nw = n_1)
        constraint_maximum_absorption(pm, i, nw = n_1)
    end

    for i in _PM.ids(pm, :ne_storage, nw = n_1)
        constraint_storage_state_ne(pm, i, nw = n_1)
        constraint_maximum_absorption_ne(pm, i, nw = n_1)
    end

    for i in _PM.ids(pm, :storage, nw = n_last)
        constraint_storage_state_final(pm, i, nw = n_last)
    end

    for i in _PM.ids(pm, :ne_storage, nw = n_last)
        constraint_storage_state_final_ne(pm, i, nw = n_last)
    end

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
        n_1 = n_2
    end

end

###########################################################
############ new storage to refernce model
##########################################################
 function add_candidate_storage!(ref::Dict{Symbol,<:Any}, data::Dict{String,<:Any})
     for (n, nw_ref) in ref[:nw]
         if haskey(nw_ref, :ne_storage)
             bus_storage_ne = Dict([(i, []) for (i,bus) in nw_ref[:bus]])
             for (i,storage) in nw_ref[:ne_storage]
                 push!(bus_storage_ne[storage["storage_bus"]], i)
             end
             nw_ref[:bus_storage_ne] = bus_storage_ne
         end
     end
 end
##################################################################
##################### Objective
##################################################################
 function objective_min_cost_storage(pm::_PM.AbstractPowerModel)
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
                 for (n, nw_ref) in _PM.nws(pm)
                     )
         )
 end



####################################################
############### Variable Definitions
###################################################
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
    # variable_storage_power_imaginary_ne(pm; kwargs...)
    # variable_storage_power_control_imaginary_ne(pm; kwargs...)
    # variable_storage_current_ne(pm; kwargs...)
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

####################################################
############### Constraint Templates
###################################################
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
    constraint_storage_state_initial(pm, nw, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
end

function constraint_storage_state_ne(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
    storage = _PM.ref(pm, nw, :ne_storage, i)

    if haskey(_PM.ref(pm, nw), :time_elapsed)
        time_elapsed = _PM.ref(pm, nw, :time_elapsed)
    else
        Memento.warn(_LOGGER, "network data should specify time_elapsed, using 1.0 as a default")
        time_elapsed = 1.0
    end
    constraint_storage_state_initial_ne(pm, nw, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
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
        constraint_storage_state(pm, nw_1, nw_2, i, storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_storage_state_initial(pm, nw_2, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
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
        constraint_storage_state_ne(pm, nw_1, nw_2, i, storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
    else
        # if the storage device has status=0 in nw_1, then the stored energy variable will not exist. Initialize storage from data model instead.
        Memento.warn(_LOGGER, "storage component $(i) was not found in network $(nw_1) while building constraint_storage_state between networks $(nw_1) and $(nw_2). Using the energy value from the storage component in network $(nw_2) instead")
        constraint_storage_state_initial_ne(pm, nw_2, i, storage["energy"], storage["charge_efficiency"], storage["discharge_efficiency"], storage["stationary_energy_inflow"], storage["stationary_energy_outflow"], time_elapsed)
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

# function constraint_storage_investment(pm::_PM.AbstractPowerModel, i::Int, nw_1::Int, nw_2::Int)
#     n_1 = nw_1
#     n_2 = nw_2
#     print(n_1,"\n")
#     print(n_2,"\n")
#     constraint_storage_investment(pm, n_1, n_2, i)
# end

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

function constraint_power_balance_acne_dcne_strg(pm::_PM.AbstractPowerModel, i::Int; nw::Int=pm.cnw)
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
    constraint_power_balance_acne_dcne_strg(pm, nw, i, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
end

####################################################
############### Constraints
###################################################
function constraint_storage_thermal_limit_ne(pm::_PM.AbstractPowerModel, n::Int, i, rating)
    ps = _PM.var(pm, n, :ps_ne, i)
    # qs = _PM.var(pm, n, :qs_ne, i)

    JuMP.@constraint(pm.model, ps <= rating)
end

function constraint_storage_losses_ne(pm::_PM.AbstractAPLossLessModels, n::Int, i, bus, r, x, p_loss, q_loss)
    ps =_PM. var(pm, n, :ps_ne, i)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)

    JuMP.@constraint(pm.model, ps + (sd - sc) == p_loss)
end

function constraint_storage_state_initial(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, inflow, outflow, time_elapsed)
    sc = _PM.var(pm, n, :sc, i)
    sd = _PM.var(pm, n, :sd, i)
    se = _PM.var(pm, n, :se, i)

    JuMP.@constraint(pm.model, se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff + inflow - outflow))
end

function constraint_storage_state_initial_ne(pm::_PM.AbstractPowerModel, n::Int, i::Int, energy, charge_eff, discharge_eff, inflow, outflow, time_elapsed)
    sc = _PM.var(pm, n, :sc_ne, i)
    sd = _PM.var(pm, n, :sd_ne, i)
    se = _PM.var(pm, n, :se_ne, i)
    z = _PM.var(pm, n, :z_strg_ne, i)

    JuMP.@constraint(pm.model, se - energy == time_elapsed*(charge_eff*sc - sd/discharge_eff + inflow * z - outflow * z))
end

function constraint_storage_state(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, inflow, outflow, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc, i)
    sd_2 = _PM.var(pm, n_2, :sd, i)
    se_2 = _PM.var(pm, n_2, :se, i)
    se_1 = _PM.var(pm, n_1, :se, i)

    JuMP.@constraint(pm.model, se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff + inflow - outflow))
end

function constraint_storage_state_ne(pm::_PM.AbstractPowerModel, n_1::Int, n_2::Int, i::Int, charge_eff, discharge_eff, inflow, outflow, time_elapsed)
    sc_2 = _PM.var(pm, n_2, :sc_ne, i)
    sd_2 = _PM.var(pm, n_2, :sd_ne, i)
    se_2 = _PM.var(pm, n_2, :se_ne, i)
    se_1 = _PM.var(pm, n_1, :se_ne, i)
    z = _PM.var(pm, n_2, :z_strg_ne, i)

    JuMP.@constraint(pm.model, se_2 - se_1 == time_elapsed*(charge_eff*sc_2 - sd_2/discharge_eff + inflow * z - outflow * z))
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

function constraint_power_balance_acne_dcne_strg(pm::_PM.AbstractDCPModel, n::Int, i::Int, bus_arcs, bus_arcs_ne, bus_arcs_dc, bus_gens, bus_convs_ac, bus_convs_ac_ne, bus_loads, bus_shunts, bus_storage, bus_storage_ne, pd, qd, gs, bs)
    p = _PM.var(pm, n, :p)
    pg = _PM.var(pm, n, :pg)
    pconv_grid_ac_ne = _PM.var(pm, n, :pconv_tf_fr_ne)
    pconv_grid_ac = _PM.var(pm, n, :pconv_tf_fr)
    pconv_ac = _PM.var(pm, n, :pconv_ac)
    pconv_ac_ne = _PM.var(pm, n, :pconv_ac_ne)
    p_ne = _PM.var(pm, n, :p_ne)
    ps   = _PM.var(pm, n, :ps)
    ps_ne   = _PM.var(pm, n, :ps_ne)
    v = 1

    JuMP.@constraint(pm.model, sum(p[a] for a in bus_arcs) + sum(p_ne[a] for a in bus_arcs_ne) + sum(pconv_grid_ac[c] for c in bus_convs_ac) + sum(pconv_grid_ac_ne[c] for c in bus_convs_ac_ne)  == sum(pg[g] for g in bus_gens) - sum(ps[s] for s in bus_storage) -sum(ps_ne[s] for s in bus_storage_ne) - sum(pd[d] for d in bus_loads) - sum(gs[s] for s in bus_shunts)*v^2)
end

