## Objective with candidate storage

function objective_min_cost_storage(pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Investment cost
    for n in nw_ids(pm; hour=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(pm,n))
    end
    # Operation cost
    for n in nw_ids(pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(pm,n))
    end
    JuMP.@objective(pm.model, Min, cost)
end

function objective_min_cost_storage(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Transmission investment cost
    for n in nw_ids(t_pm; hour=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(t_pm,n))
    end
    # Transmission operation cost
    for n in nw_ids(t_pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(t_pm,n))
    end
    # Distribution investment cost
    for n in nw_ids(d_pm; hour=1)
        # Note: distribution networks do not have DC components (modeling decision)
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(d_pm,n))
    end
    # Distribution operation cost
    for n in nw_ids(d_pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(d_pm,n))
    end
    JuMP.@objective(t_pm.model, Min, cost) # Note: t_pm.model == d_pm.model
end


## Objective with candidate storage and flexible demand

function objective_min_cost_flex(pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Investment cost
    for n in nw_ids(pm; hour=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(pm,n))
    end
    # Operation cost
    for n in nw_ids(pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_load_operation_cost(pm,n))
    end
    JuMP.@objective(pm.model, Min, cost)
end

function objective_min_cost_flex(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Transmission investment cost
    for n in nw_ids(t_pm; hour=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(t_pm,n))
    end
    # Transmission operation cost
    for n in nw_ids(t_pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_load_operation_cost(t_pm,n))
    end
    # Distribution investment cost
    for n in nw_ids(d_pm; hour=1)
        # Note: distribution networks do not have DC components (modeling decision)
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(d_pm,n))
    end
    # Distribution operation cost
    for n in nw_ids(d_pm)
        JuMP.add_to_expression!(cost, calc_gen_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_load_operation_cost(d_pm,n))
    end
    JuMP.@objective(t_pm.model, Min, cost) # Note: t_pm.model == d_pm.model
end


## Stochastic objective with candidate storage and flexible demand

function objective_stoch_flex(pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Investment cost
    for n in nw_ids(pm; hour=1, scenario=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(pm,n))
    end
    # Operation cost
    for (s, scenario) in dim_prop(pm, :scenario)
        scenario_probability = scenario["probability"]
        for n in nw_ids(pm; scenario=s)
            JuMP.add_to_expression!(cost, scenario_probability, calc_gen_cost(pm,n))
            JuMP.add_to_expression!(cost, scenario_probability, calc_load_operation_cost(pm,n))
        end
    end
    JuMP.@objective(pm.model, Min, cost)
end

function objective_stoch_flex(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractPowerModel)
    cost = JuMP.AffExpr(0.0)
    # Transmission investment cost
    for n in nw_ids(t_pm; hour=1, scenario=1)
        JuMP.add_to_expression!(cost, calc_convdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_branchdc_ne_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(t_pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(t_pm,n))
    end
    # Transmission operation cost
    for (s, scenario) in dim_prop(t_pm, :scenario)
        scenario_probability = scenario["probability"]
        for n in nw_ids(t_pm; scenario=s)
            JuMP.add_to_expression!(cost, scenario_probability, calc_gen_cost(t_pm,n))
            JuMP.add_to_expression!(cost, scenario_probability, calc_load_operation_cost(t_pm,n))
        end
    end
    # Distribution investment cost
    for n in nw_ids(d_pm; hour=1, scenario=1)
        # Note: distribution networks do not have DC components (modeling decision)
        JuMP.add_to_expression!(cost, calc_ne_branch_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_ne_storage_cost(d_pm,n))
        JuMP.add_to_expression!(cost, calc_load_investment_cost(d_pm,n))
    end
    # Distribution operation cost
    for (s, scenario) in dim_prop(d_pm, :scenario)
        scenario_probability = scenario["probability"]
        for n in nw_ids(d_pm; scenario=s)
            JuMP.add_to_expression!(cost, scenario_probability, calc_gen_cost(d_pm,n))
            JuMP.add_to_expression!(cost, scenario_probability, calc_load_operation_cost(d_pm,n))
        end
    end
    JuMP.@objective(t_pm.model, Min, cost) # Note: t_pm.model == d_pm.model
end


## Auxiliary functions

function calc_gen_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = JuMP.AffExpr(0.0)
    for (i,g) in _PM.ref(pm, n, :gen)
        if length(g["cost"]) ≥ 2
            JuMP.add_to_expression!(cost, g["cost"][end-1], _PM.var(pm,n,:pg,i))
        end
    end
    if get(pm.setting, "add_co2_cost", false)
        co2_emission_cost = pm.ref[:it][_PM.pm_it_sym][:co2_emission_cost]
        for (i,g) in _PM.ref(pm, n, :dgen)
            JuMP.add_to_expression!(cost, g["emission_factor"]*co2_emission_cost, _PM.var(pm,n,:pg,i))
        end
    end
    for (i,g) in _PM.ref(pm, n, :ndgen)
        JuMP.add_to_expression!(cost, g["cost_curt"], _PM.var(pm,n,:pgcurt,i))
    end
    return cost
end

function calc_convdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int)
    add_co2_cost = get(pm.setting, "add_co2_cost", false)
    cost = JuMP.AffExpr(0.0)
    for (i,conv) in get(_PM.ref(pm,n), :convdc_ne, Dict())
        conv_cost = conv["cost"]
        if add_co2_cost
            conv_cost += conv["co2_cost"]
        end
        JuMP.add_to_expression!(cost, conv_cost, _PM.var(pm,n,:conv_ne_investment,i))
    end
    return cost
end

function calc_ne_branch_cost(pm::_PM.AbstractPowerModel, n::Int)
    add_co2_cost = get(pm.setting, "add_co2_cost", false)
    cost = JuMP.AffExpr(0.0)
    for (i,branch) in get(_PM.ref(pm,n), :ne_branch, Dict())
        branch_cost = branch["construction_cost"]
        if add_co2_cost
            branch_cost += branch["co2_cost"]
        end
        JuMP.add_to_expression!(cost, branch_cost, _PM.var(pm,n,:branch_ne_investment,i))
    end
    return cost
end

function calc_branchdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int)
    add_co2_cost = get(pm.setting, "add_co2_cost", false)
    cost = JuMP.AffExpr(0.0)
    for (i,branch) in get(_PM.ref(pm,n), :branchdc_ne, Dict())
        branch_cost = branch["cost"]
        if add_co2_cost
            branch_cost += branch["co2_cost"]
        end
        JuMP.add_to_expression!(cost, branch_cost, _PM.var(pm,n,:branchdc_ne_investment,i))
    end
    return cost
end

function calc_ne_storage_cost(pm::_PM.AbstractPowerModel, n::Int)
    add_co2_cost = get(pm.setting, "add_co2_cost", false)
    cost = JuMP.AffExpr(0.0)
    for (i,storage) in get(_PM.ref(pm,n), :ne_storage, Dict())
        storage_cost = storage["eq_cost"] + storage["inst_cost"]
        if add_co2_cost
            storage_cost += storage["co2_cost"]
        end
        JuMP.add_to_expression!(cost, storage_cost, _PM.var(pm,n,:z_strg_ne_investment,i))
    end
    return cost
end

function calc_load_operation_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = JuMP.AffExpr(0.0)
    for (i,l) in _PM.ref(pm, n, :flex_load)
        JuMP.add_to_expression!(cost, 0.5*l["cost_shift"], _PM.var(pm,n,:pshift_up,i)) # Splitting into half and half allows for better cost attribution when running single-period problems or problems with no integral constraints.
        JuMP.add_to_expression!(cost, 0.5*l["cost_shift"], _PM.var(pm,n,:pshift_down,i))
        JuMP.add_to_expression!(cost, l["cost_red"], _PM.var(pm,n,:pred,i))
        JuMP.add_to_expression!(cost, l["cost_curt"], _PM.var(pm,n,:pcurt,i))
    end
    for (i,l) in _PM.ref(pm, n, :fixed_load)
        JuMP.add_to_expression!(cost, l["cost_curt"], _PM.var(pm,n,:pcurt,i))
    end
    return cost
end

function calc_load_investment_cost(pm::_PM.AbstractPowerModel, n::Int)
    add_co2_cost = get(pm.setting, "add_co2_cost", false)
    cost = JuMP.AffExpr(0.0)
    for (i,l) in _PM.ref(pm, n, :flex_load)
        load_cost = l["cost_inv"]
        if add_co2_cost
            load_cost += l["co2_cost"]
        end
        JuMP.add_to_expression!(cost, load_cost, _PM.var(pm,n,:z_flex_investment,i))
    end
    return cost
end
