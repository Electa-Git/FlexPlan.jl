export flex_tnep

""
function flex_tnep(data::Dict{String,Any}, model_type::Type, solver; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
    s = setting
    return _PM.run_model(data, model_type, solver, post_flex_tnep; ref_extensions = [_PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, add_candidate_storage!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!], setting = s, kwargs...)
end

# Here the problem is defined, which is then sent to the solver.
# It is basically a declarion of variables and constraint of the problem

""
function post_flex_tnep(pm::_PM.AbstractPowerModel)
# VARIABLES: defined within PowerModels(ACDC) can directly be used, other variables need to be defined in the according sections of the code: flexible_demand.jl    
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
#OBJECTIVE see objective.jl
    objective_min_cost_flex(pm)
#CONSTRAINTS: defined within PowerModels(ACDC) can directly be used, other constraints need to be defined in the according sections of the code: flexible_demand.jl   
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
        if haskey(pm.setting, "allow_line_replacement") && pm.setting["allow_line_replacement"] == true
            for i in _PM.ids(pm, n, :branch)
                constraint_ohms_yt_from_repl(pm, i; nw = n)
                constraint_ohms_yt_to_repl(pm, i; nw = n)
                constraint_voltage_angle_difference_repl(pm, i; nw = n)
                constraint_thermal_limit_from_repl(pm, i; nw = n)
                constraint_thermal_limit_to_repl(pm, i; nw = n)
            end
        else    
            for i in _PM.ids(pm, n, :branch)
                _PM.constraint_ohms_yt_from(pm, i; nw = n)
                _PM.constraint_ohms_yt_to(pm, i; nw = n)
                _PM.constraint_voltage_angle_difference(pm, i; nw = n)
                _PM.constraint_thermal_limit_from(pm, i; nw = n)
                _PM.constraint_thermal_limit_to(pm, i; nw = n)
            end
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
                constraint_shift_duration(pm, n_2, i)
                constraint_flex_investment(pm, n_1, n_2, i)
            end
        end
        n_1 = n_2
    end
end