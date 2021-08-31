##################################################################
##################### Objective with candidate storage
##################################################################

function objective_min_cost_storage(pm::_PM.AbstractPowerModel)
    investment = sum(
        calc_convdc_ne_cost(pm, n)
        + calc_ne_branch_cost(pm, n)
        + calc_branchdc_ne_cost(pm, n)
        + calc_ne_storage_cost(pm, n)
        for n in nw_ids(pm; hour=1)
    )
    operation = sum(
        calc_gen_cost(pm, n)
        for n in nw_ids(pm)
    )
    JuMP.@objective(pm.model, Min, investment + operation)
end


#################################################################
##################### Objective with candidate storage and flexible demand
##################################################################

function objective_min_cost_flex(pm::_PM.AbstractPowerModel)
    investment = sum(
        calc_convdc_ne_cost(pm, n)
        + calc_ne_branch_cost(pm, n)
        + calc_branchdc_ne_cost(pm, n)
        + calc_ne_storage_cost(pm, n)
        + calc_load_investment_cost(pm, n)
        for n in nw_ids(pm; hour=1)
    )
    operation = sum(
        calc_gen_cost(pm, n)
        + calc_load_operational_cost(pm, n)
        for n in nw_ids(pm)
    )
    JuMP.@objective(pm.model, Min, investment + operation)
end

function objective_min_cost_flex(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractPowerModel)
    return JuMP.@objective(t_pm.model, Min, # Note: t_pm.model == d_pm.model
        # Cost related to transmission (multi)network
        sum(
            calc_gen_cost(t_pm, n)
            + calc_convdc_ne_cost(t_pm, n)
            + calc_ne_branch_cost(t_pm, n)
            + calc_branchdc_ne_cost(t_pm, n)
            + calc_ne_storage_cost(t_pm, n)
            + calc_load_cost(t_pm, n)
        for n in nw_ids(t_pm))
        +
        # Cost related to distribution (multi)network
        # Note: distribution networks do not have DC components (modeling decision)
        sum(
            calc_gen_cost(d_pm, n)
            + calc_ne_branch_cost(d_pm, n)
            + calc_ne_storage_cost(d_pm, n)
            + calc_load_cost(d_pm, n)
        for n in nw_ids(d_pm))
    )
end


##########################################################################
##################### Stochastic objective with storage & flex candidates
##########################################################################

function objective_stoch_flex(pm::_PM.AbstractPowerModel)
    investment = sum(
        calc_convdc_ne_cost(pm, n)
        + calc_ne_branch_cost(pm, n)
        + calc_branchdc_ne_cost(pm, n)
        + calc_ne_storage_cost(pm, n)
        + calc_load_investment_cost(pm, n)
        for n in nw_ids(pm; hour=1, scenario=1)
    )
    operation = sum(scenario["probability"] *
        sum(
            calc_gen_cost(pm, n)
            + calc_load_operational_cost(pm, n)
            for n in nw_ids(pm; scenario=s)
        )
        for (s, scenario) in dim_prop(pm, :scenario)
    )
    JuMP.@objective(pm.model, Min, investment + operation)
end


##########################################################################
##################### Reliability objective with storage & flex candidates
##########################################################################

function objective_reliability(pm::_PM.AbstractPowerModel)
    return JuMP.@objective(pm.model, Min,
        sum(pm.ref[:contingency_prob][s] *
            sum(
                calc_gen_cost(pm, n)
                + calc_convdc_ne_cost(pm, n)
                + calc_ne_branch_cost(pm, n)
                + calc_branchdc_ne_cost(pm, n)
                + calc_ne_storage_cost(pm, n)
                + calc_load_cost(pm, n)
                + calc_contingency_cost(pm, n)
            for (sc, n) in contingency)
        for (s, contingency) in pm.ref[:contingency])
    )
end


##########################################################################
##################### Auxiliary functions
##########################################################################

function calc_gen_cost(pm::_PM.AbstractPowerModel, n::Int)

    function calc_single_gen_cost(i, g_cost)
        len = length(g_cost)
        cost = 0.0
        if len >= 1
            cost = g_cost[len] # Constant term
            if len >= 2
                cost += g_cost[len-1] * _PM.var(pm,n,:pg,i) # Adds linear term
            end
        end
        return cost
    end

    gen = _PM.ref(pm, n, :gen)
    cost = sum(calc_single_gen_cost(i,g["cost"]) for (i,g) in gen)
    if get(pm.setting, "add_co2_cost", false)
        cost += sum(g["emission_factor"] * _PM.var(pm,n,:pg,i) * pm.ref[:co2_emission_cost] for (i,g) in gen)
    end
    return cost
end

function calc_convdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :convdc_ne)
        convdc_ne = _PM.ref(pm, n, :convdc_ne)
        if !isempty(convdc_ne)
            cost = sum(conv["cost"]*_PM.var(pm, n, :conv_ne_investment, i) for (i,conv) in convdc_ne)
            if get(pm.setting, "add_co2_cost", false)
                cost += sum(conv["co2_cost"]*_PM.var(pm, n, :conv_ne_investment, i) for (i,conv) in convdc_ne)
            end
        end
    end
    return cost
end

function calc_ne_branch_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :ne_branch)
        ne_branch = _PM.ref(pm, n, :ne_branch)
        if !isempty(ne_branch)
            cost = sum(branch["construction_cost"]*_PM.var(pm, n, :branch_ne_investment, i) for (i,branch) in ne_branch)
            if get(pm.setting, "add_co2_cost", false)
                cost += sum(branch["co2_cost"]*_PM.var(pm, n, :branch_ne_investment, i) for (i,branch) in ne_branch)
            end
        end
    end
    return cost
end

function calc_branchdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :branchdc_ne)
        branchdc_ne = _PM.ref(pm, n, :branchdc_ne)
        if !isempty(branchdc_ne)
            cost = sum(branch["cost"]*_PM.var(pm, n, :branchdc_ne_investment, i) for (i,branch) in branchdc_ne)
            if get(pm.setting, "add_co2_cost", false)
                cost += sum(branch["co2_cost"]*_PM.var(pm, n, :branchdc_ne_investment, i) for (i,branch) in branchdc_ne)
            end
        end
    end
    return cost
end

function calc_ne_storage_cost(pm::_PM.AbstractPowerModel, n::Int)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :ne_storage)
        ne_storage = _PM.ref(pm, n, :ne_storage)
        if !isempty(ne_storage)
            cost = sum((storage["eq_cost"] + storage["inst_cost"])*_PM.var(pm, n, :z_strg_ne_investment, i) for (i,storage) in ne_storage)
            if get(pm.setting, "add_co2_cost", false)
                cost += sum(storage["co2_cost"]*_PM.var(pm, n, :z_strg_ne_investment, i) for (i,storage) in ne_storage)
            end
        end
    end
    return cost
end

function calc_load_cost(pm::_PM.AbstractPowerModel, n::Int)
    return calc_load_operational_cost(pm, n) + calc_load_investment_cost(pm, n)
end

function calc_load_operational_cost(pm::_PM.AbstractPowerModel, n::Int)
    load = _PM.ref(pm, n, :load)
    cost = sum(
        l["cost_shift_up"]*_PM.var(pm, n, :pshift_up, i)
        + l["cost_shift_down"]*_PM.var(pm, n, :pshift_down, i)
        + l["cost_reduction"]*_PM.var(pm, n, :pnce, i)
        + l["cost_curtailment"]*_PM.var(pm, n, :pcurt, i)
        for (i,l) in load
    )
    return cost
end

function calc_load_investment_cost(pm::_PM.AbstractPowerModel, n::Int)
    load = _PM.ref(pm, n, :load)
    cost = sum(l["cost_investment"]*_PM.var(pm, n, :z_flex_investment, i) for (i,l) in load)
    if get(pm.setting, "add_co2_cost", false)
        cost += sum(l["co2_cost"]*_PM.var(pm, n, :z_flex_investment, i) for (i,l) in load)
    end
    return cost
end

function calc_contingency_cost(pm::_PM.AbstractPowerModel, n::Int)
    load = _PM.ref(pm, n, :load)
    cost = 0.0
    if n ∉ [parse(Int, t) for t in keys(pm.ref[:contingency]["0"])]
        cost += sum(l["cost_voll"]*_PM.var(pm, n, :pinter, i) for (i,l) in load)
    end
    return cost
end