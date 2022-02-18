export simple_stoch_flex_tnep

"Multi-scenario TNEP with flexible loads and storage, for transmission networks"
function simple_stoch_flex_tnep(data::Dict{String,Any}, model_type::Type, optimizer; kwargs...)
    require_dim(data, :hour, :scenario, :year)
    return _PM.run_model(
        data, model_type, optimizer, post_simple_stoch_flex_tnep;
        ref_extensions = [ref_add_gen!, _PMACDC.add_ref_dcgrid!, _PMACDC.add_candidate_dcgrid!, ref_add_storage!, ref_add_ne_storage!, ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, _PM.ref_add_ne_branch!],
        multinetwork = true,
        kwargs...
    )
end

"Multi-scenario TNEP with flexible loads and storage, for distribution networks"
function simple_stoch_flex_tnep(data::Dict{String,Any}, model_type::Type{<:_PM.AbstractBFModel}, optimizer; kwargs...)
    require_dim(data, :hour, :scenario, :year)
    return _PM.run_model(
        data, model_type, optimizer, post_simple_stoch_flex_tnep;
        ref_extensions = [ref_add_gen!, ref_add_storage!, ref_add_ne_storage!, ref_add_flex_load!, _PM.ref_add_on_off_va_bounds!, ref_add_ne_branch_allbranches!, ref_add_frb_branch!, ref_add_oltc_branch!],
        solution_processors = [_PM.sol_data_model!],
        multinetwork = true,
        kwargs...
    )
end


# Here the problem is defined, which is then sent to the solver.
# It is basically a declaration of variables and constraints of the problem

"Builds transmission model."
function post_simple_stoch_flex_tnep(pm::_PM.AbstractPowerModel)
    # VARIABLES: defined within PowerModels(ACDC) can directly be used, other variables need to be defined in the according sections of the code
    for n in nw_ids(pm)

        # AC Bus
        _PM.variable_bus_voltage(pm; nw = n)

        # AC branch
        _PM.variable_branch_power(pm; nw = n)

        # DC bus
        _PMACDC.variable_dcgrid_voltage_magnitude(pm; nw = n)

        # DC branch
        _PMACDC.variable_active_dcbranch_flow(pm; nw = n)
        _PMACDC.variable_dcbranch_current(pm; nw = n)

        # AC-DC converter
        _PMACDC.variable_dc_converter(pm; nw = n)

        # Generator
        _PM.variable_gen_power(pm; nw = n)
        expression_gen_curtailment(pm; nw = n)

        # Storage
        _PM.variable_storage_power(pm; nw = n)
        variable_absorbed_energy(pm; nw = n)

        # Candidate AC branch
        variable_ne_branch_investment(pm; nw = n)
        variable_ne_branch_indicator(pm; nw = n, relax=true) # FlexPlan version: replaces _PM.variable_ne_branch_indicator().
        _PM.variable_ne_branch_power(pm; nw = n)
        _PM.variable_ne_branch_voltage(pm; nw = n)

        # Candidate DC bus
        _PMACDC.variable_dcgrid_voltage_magnitude_ne(pm; nw = n)

        # Candidate DC branch
        variable_ne_branchdc_investment(pm; nw = n)
        variable_ne_branchdc_indicator(pm; nw = n, relax=true) # FlexPlan version: replaces _PMACDC.variable_branch_ne().
        _PMACDC.variable_active_dcbranch_flow_ne(pm; nw = n)
        _PMACDC.variable_dcbranch_current_ne(pm; nw = n)

        # Candidate AC-DC converter
        variable_dc_converter_ne(pm; nw = n) # FlexPlan version: replaces _PMACDC.variable_dc_converter_ne().
        _PMACDC.variable_voltage_slack(pm; nw = n)

        # Candidate storage
        variable_storage_power_ne(pm; nw = n)
        variable_absorbed_energy_ne(pm; nw = n)

        # Flexible demand
        variable_flexible_demand(pm; nw = n)
    end

    # OBJECTIVE: see objective.jl
    objective_stoch_flex(pm)

    # CONSTRAINTS: defined within PowerModels(ACDC) can directly be used, other constraints need to be defined in the according sections of the code
    for n in nw_ids(pm)
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
        for i in _PM.ids(pm, n, :branchdc_ne)
            _PMACDC.constraint_ohms_dc_branch_ne(pm, i; nw = n)
            _PMACDC.constraint_branch_limit_on_off(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :convdc)
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
            _PMACDC.constraint_conv_transformer_ne(pm, i; nw = n)
            _PMACDC.constraint_conv_reactor_ne(pm, i; nw = n)
            _PMACDC.constraint_conv_filter_ne(pm, i; nw = n)
            if pm.ref[:nw][n][:convdc_ne][i]["islcc"] == 1
                _PMACDC.constraint_conv_firing_angle_ne(pm, i; nw = n)
            end
        end

        for i in _PM.ids(pm, n, :flex_load)
            constraint_total_flexible_demand(pm, i; nw = n)
            constraint_flex_bounds_ne(pm, i; nw = n)
        end
        for i in _PM.ids(pm, n, :fixed_load)
            constraint_total_fixed_demand(pm, i; nw = n)
        end

        for i in _PM.ids(pm, :storage, nw=n)
            _PM.constraint_storage_thermal_limit(pm, i, nw = n)
            _PM.constraint_storage_losses(pm, i, nw = n)
        end
        for i in _PM.ids(pm, :ne_storage, nw=n)
            constraint_storage_thermal_limit_ne(pm, i, nw = n)
            constraint_storage_losses_ne(pm, i, nw = n)
            constraint_storage_bounds_ne(pm, i, nw = n)
        end

        if is_first_id(pm, n, :hour)
            for i in _PM.ids(pm, :storage, nw = n)
                constraint_storage_state(pm, i, nw = n)
            end
            for i in _PM.ids(pm, :storage_bounded_absorption, nw = n)
                constraint_maximum_absorption(pm, i, nw = n)
            end

            for i in _PM.ids(pm, :ne_storage, nw = n)
                constraint_storage_state_ne(pm, i, nw = n)
            end
            for i in _PM.ids(pm, :ne_storage_bounded_absorption, nw = n)
                constraint_maximum_absorption_ne(pm, i, nw = n)
            end
        else
            if is_last_id(pm, n, :hour)
                for i in _PM.ids(pm, :storage, nw = n)
                    constraint_storage_state_final(pm, i, nw = n)
                end

                for i in _PM.ids(pm, :ne_storage, nw = n)
                    constraint_storage_state_final_ne(pm, i, nw = n)
                end

                for i in _PM.ids(pm, :flex_load, nw = n)
                    constraint_shift_balance_periodic(pm, i, get(pm.setting, "demand_shifting_balance_period", 24), nw = n)
                end
            end

            # From second hour to last hour
            prev_n = prev_id(pm, n, :hour)
            first_n = first_id(pm, n, :hour)
            for i in _PM.ids(pm, :storage, nw = n)
                constraint_storage_state(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :storage_bounded_absorption, nw = n)
                constraint_maximum_absorption(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :ne_storage, nw = n)
                constraint_storage_state_ne(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :ne_storage_bounded_absorption, nw = n)
                constraint_maximum_absorption_ne(pm, i, prev_n, n)
            end
        end

        # Constraints on investments
        if is_first_id(pm, n, :hour, :scenario)
            # Inter-year constraints
            prev_nws = prev_ids(pm, n, :year)
            for i in _PM.ids(pm, :ne_branch; nw = n)
                constraint_ne_branch_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :branchdc_ne; nw = n)
                constraint_ne_branchdc_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :convdc_ne; nw = n)
                constraint_ne_converter_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :ne_storage; nw = n)
                constraint_ne_storage_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :flex_load; nw = n)
                constraint_flexible_demand_activation(pm, i, prev_nws, n)
            end
        end
    end
end

"Builds distribution model."
function post_simple_stoch_flex_tnep(pm::_PM.AbstractBFModel)

    for n in nw_ids(pm)

        # AC Bus
        _PM.variable_bus_voltage(pm; nw = n)

        # AC branch
        _PM.variable_branch_power(pm; nw = n)
        _PM.variable_branch_current(pm; nw = n)
        variable_oltc_branch_transform(pm; nw = n)

        # Generator
        _PM.variable_gen_power(pm; nw = n)
        expression_gen_curtailment(pm; nw = n)

        # Storage
        _PM.variable_storage_power(pm; nw = n)
        variable_absorbed_energy(pm; nw = n)

        # Candidate AC branch
        variable_ne_branch_investment(pm; nw = n)
        variable_ne_branch_indicator(pm; nw = n, relax=true) # FlexPlan version: replaces _PM.variable_ne_branch_indicator().
        _PM.variable_ne_branch_power(pm; nw = n, bounded = false) # Bounds computed here would be too limiting in the case of ne_branches added in parallel
        variable_ne_branch_current(pm; nw = n)
        variable_oltc_ne_branch_transform(pm; nw = n)

        # Candidate storage
        variable_storage_power_ne(pm; nw = n)
        variable_absorbed_energy_ne(pm; nw = n)

        # Flexible demand
        variable_flexible_demand(pm; nw = n)
    end

    objective_stoch_flex(pm)

    for n in nw_ids(pm)
        _PM.constraint_model_current(pm; nw = n)
        constraint_ne_model_current(pm; nw = n)

        if haskey(dim_prop(pm), :sub_nw)
            constraint_td_coupling_power_reactive_bounds(pm; nw = n)
        end

        for i in _PM.ids(pm, n, :ref_buses)
            _PM.constraint_theta_ref(pm, i, nw = n)
        end

        for i in _PM.ids(pm, n, :bus)
            constraint_power_balance_acne_flex(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :branch)
            constraint_dist_branch_tnep(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :ne_branch)
            constraint_dist_ne_branch_tnep(pm, i; nw = n)
        end

        for i in _PM.ids(pm, n, :flex_load)
            constraint_total_flexible_demand(pm, i; nw = n)
            constraint_flex_bounds_ne(pm, i; nw = n)
        end
        for i in _PM.ids(pm, n, :fixed_load)
            constraint_total_fixed_demand(pm, i; nw = n)
        end

        for i in _PM.ids(pm, :storage, nw=n)
            _PM.constraint_storage_thermal_limit(pm, i, nw = n)
            _PM.constraint_storage_losses(pm, i, nw = n)
        end
        for i in _PM.ids(pm, :ne_storage, nw=n)
            constraint_storage_thermal_limit_ne(pm, i, nw = n)
            constraint_storage_losses_ne(pm, i, nw = n)
            constraint_storage_bounds_ne(pm, i, nw = n)
        end

        if is_first_id(pm, n, :hour)
            for i in _PM.ids(pm, :storage, nw = n)
                constraint_storage_state(pm, i, nw = n)
            end
            for i in _PM.ids(pm, :storage_bounded_absorption, nw = n)
                constraint_maximum_absorption(pm, i, nw = n)
            end

            for i in _PM.ids(pm, :ne_storage, nw = n)
                constraint_storage_state_ne(pm, i, nw = n)
            end
            for i in _PM.ids(pm, :ne_storage_bounded_absorption, nw = n)
                constraint_maximum_absorption_ne(pm, i, nw = n)
            end
        else
            if is_last_id(pm, n, :hour)
                for i in _PM.ids(pm, :storage, nw = n)
                    constraint_storage_state_final(pm, i, nw = n)
                end

                for i in _PM.ids(pm, :ne_storage, nw = n)
                    constraint_storage_state_final_ne(pm, i, nw = n)
                end

                for i in _PM.ids(pm, :flex_load, nw = n)
                    constraint_shift_balance_periodic(pm, i, get(pm.setting, "demand_shifting_balance_period", 24), nw = n)
                end
            end

            # From second hour to last hour
            prev_n = prev_id(pm, n, :hour)
            first_n = first_id(pm, n, :hour)
            for i in _PM.ids(pm, :storage, nw = n)
                constraint_storage_state(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :storage_bounded_absorption, nw = n)
                constraint_maximum_absorption(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :ne_storage, nw = n)
                constraint_storage_state_ne(pm, i, prev_n, n)
            end
            for i in _PM.ids(pm, :ne_storage_bounded_absorption, nw = n)
                constraint_maximum_absorption_ne(pm, i, prev_n, n)
            end
        end

        # Constraints on investments
        if is_first_id(pm, n, :hour, :scenario)
            for i in _PM.ids(pm, n, :branch)
                if !isempty(ne_branch_ids(pm, i; nw = n))
                    constraint_branch_complementarity(pm, i; nw = n)
                end
            end

            # Inter-year constraints
            prev_nws = prev_ids(pm, n, :year)
            for i in _PM.ids(pm, :ne_branch; nw = n)
                constraint_ne_branch_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :ne_storage; nw = n)
                constraint_ne_storage_activation(pm, i, prev_nws, n)
            end
            for i in _PM.ids(pm, :flex_load; nw = n)
                constraint_flexible_demand_activation(pm, i, prev_nws, n)
            end
        end
    end
end