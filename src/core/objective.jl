##################################################################
##################### Objective with candidate storage
##################################################################
function objective_min_cost_storage(pm::_PM.AbstractPowerModel)
    add_co2_cost = haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"]
    return JuMP.@objective(pm.model, Min,
        sum(
            calc_gen_cost(pm, n, add_co2_cost)
            + calc_convdc_ne_cost(pm, n, add_co2_cost)
            + calc_ne_branch_cost(pm, n, add_co2_cost)
            + calc_branchdc_ne_cost(pm, n, add_co2_cost)
            + calc_ne_storage_cost(pm, n, add_co2_cost)
        for (n, nw_ref) in _PM.nws(pm))
    )
end


#################################################################
##################### Objective with candidate storage and flexible demand
##################################################################

function objective_min_cost_flex(pm::_PM.AbstractPowerModel)
    add_co2_cost = haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"]
    return JuMP.@objective(pm.model, Min,
        sum(
            calc_gen_cost(pm, n, add_co2_cost)
            + calc_convdc_ne_cost(pm, n, add_co2_cost)
            + calc_ne_branch_cost(pm, n, add_co2_cost)
            + calc_branchdc_ne_cost(pm, n, add_co2_cost)
            + calc_ne_storage_cost(pm, n, add_co2_cost)
            + calc_load_cost(pm, n, add_co2_cost)
        for (n, nw_ref) in _PM.nws(pm))
    )
end

function objective_min_cost_flex(t_pm::_PM.AbstractPowerModel, d_pm::_PM.AbstractPowerModel)
    add_co2_cost = haskey(t_pm.setting, "add_co2_cost") && t_pm.setting["add_co2_cost"] # Note: t_pm.setting == d_pm.setting
    return JuMP.@objective(t_pm.model, Min, # Note: t_pm.model == d_pm.model
        # Cost related to transmission (multi)network
        sum(
            calc_gen_cost(t_pm, n, add_co2_cost)
            + calc_convdc_ne_cost(t_pm, n, add_co2_cost)
            + calc_ne_branch_cost(t_pm, n, add_co2_cost)
            + calc_branchdc_ne_cost(t_pm, n, add_co2_cost)
            + calc_ne_storage_cost(t_pm, n, add_co2_cost)
            + calc_load_cost(t_pm, n, add_co2_cost)
        for (n, nw_ref) in _PM.nws(t_pm))
        +
        # Cost related to distribution (multi)network
        # Note: distribution networks do not have DC components (modeling decision)
        sum(
            calc_gen_cost(d_pm, n, add_co2_cost)
            + calc_ne_branch_cost(d_pm, n, add_co2_cost)
            + calc_ne_storage_cost(d_pm, n, add_co2_cost)
            + calc_load_cost(d_pm, n, add_co2_cost)
        for (n, nw_ref) in _PM.nws(d_pm))
    )
end

##########################################################################
##################### Stochastic objective with storage & flex candidates
##########################################################################
function objective_stoch_flex(pm::_PM.AbstractPowerModel)
    add_co2_cost = haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"]
    return JuMP.@objective(pm.model, Min,
        sum(pm.ref[:scenario_prob][s] * 
            sum(
                calc_gen_cost(pm, n, add_co2_cost)
                + calc_convdc_ne_cost(pm, n, add_co2_cost)
                + calc_ne_branch_cost(pm, n, add_co2_cost)
                + calc_branchdc_ne_cost(pm, n, add_co2_cost)
                + calc_ne_storage_cost(pm, n, add_co2_cost)
                + calc_load_cost(pm, n, add_co2_cost)
            for (sc, n) in scenario)
        for (s, scenario) in pm.ref[:scenario])
    )
end


##########################################################################
##################### Auxiliary functions
##########################################################################

function calc_gen_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)

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
    if add_co2_cost
        cost += sum(g["emission_factor"] * _PM.var(pm,n,:pg,i) * pm.ref[:co2_emission_cost] for (i,g) in gen)
    end
    return cost
end

##########################################################################
##################### Reliability objective with storage & flex candidates
##########################################################################
function objective_reliability(pm::_PM.AbstractPowerModel)
    gen_cost = Dict()
    for (s, contingency) in pm.ref[:contingency]
        for (sc, n) in contingency
            for (i,gen) in pm.ref[:nw][n][:gen]
                pg = _PM.var(pm, n, :pg, i)
                if length(gen["cost"]) == 1
                    gen_cost[(n,i)] = gen["cost"][1]
                elseif length(gen["cost"]) == 2
                    gen_cost[(n,i)] = (gen["cost"][1]*pg + gen["cost"][2])
                elseif length(gen["cost"]) == 3
                    gen_cost[(n,i)] = (gen["cost"][2]*pg + gen["cost"][3])
                else
                    gen_cost[(n,i)] = 0.0
                end
                if haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"] == true
                    gen_cost[(n,i)] = gen_cost[(n,i)] + gen["emission_factor"] * pg * pm.ref[:co2_emission_cost]
                end
            end
        end
    end
    return JuMP.@objective(pm.model, Min,
    sum(pm.ref[:contingency_prob][s] * 
        sum(
            sum(gen_cost[(n,i)] for (i,gen) in pm.ref[:nw][n][:gen]) + calculate_inv_cost(pm, n, is_contingency=true)
            for (sc, n) in contingency # All times in a contingency scenario
                ) 
        for (s, contingency) in pm.ref[:contingency] # All contingency
            )
    )
end

function calculate_inv_cost(pm::_PM.AbstractPowerModel, n::Int; is_contingency::Bool=false)
    if haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"] == true
        inv_cost = (
            sum(conv["cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in pm.ref[:nw][n][:convdc_ne])
            +
            sum(conv["co2_cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in pm.ref[:nw][n][:convdc_ne])
            +
            sum(branch["construction_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in pm.ref[:nw][n][:ne_branch])
            +
            sum(branch["co2_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in pm.ref[:nw][n][:ne_branch])
            +
            sum(branch["cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in pm.ref[:nw][n][:branchdc_ne])
            +
            sum(branch["co2_cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in pm.ref[:nw][n][:branchdc_ne])
            +
            sum((storage["eq_cost"] + storage["inst_cost"] + storage["co2_cost"])*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in pm.ref[:nw][n][:ne_storage])
            +
            sum(load["cost_shift_up"]*_PM.var(pm, n, :pshift_up, i) for (i,load) in pm.ref[:nw][n][:load])
            +
            sum(load["cost_shift_down"]*_PM.var(pm, n, :pshift_down, i) for (i,load) in pm.ref[:nw][n][:load])
            +
            sum(load["cost_reduction"]*_PM.var(pm, n, :pnce, i) for (i,load) in pm.ref[:nw][n][:load])
            +
            sum(load["cost_curtailment"]*_PM.var(pm, n, :pcurt, i) for (i,load) in pm.ref[:nw][n][:load])
            +
            sum(load["co2_cost"]*_PM.var(pm, n, :z_flex, i) for (i,load) in pm.ref[:nw][n][:load])
            )
    else
        inv_cost = (
        sum(conv["cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in pm.ref[:nw][n][:convdc_ne])
        +
        sum(branch["construction_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in pm.ref[:nw][n][:ne_branch])
        +
        sum(branch["cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in pm.ref[:nw][n][:branchdc_ne])
        +
        sum((storage["eq_cost"] + storage["inst_cost"])*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in pm.ref[:nw][n][:ne_storage])
        +
        sum(load["cost_shift_up"]*_PM.var(pm, n, :pshift_up, i) for (i,load) in pm.ref[:nw][n][:load])
        +
        sum(load["cost_shift_down"]*_PM.var(pm, n, :pshift_down, i) for (i,load) in pm.ref[:nw][n][:load])
        +
        sum(load["cost_reduction"]*_PM.var(pm, n, :pnce, i) for (i,load) in pm.ref[:nw][n][:load])
        +
        sum(load["cost_curtailment"]*_PM.var(pm, n, :pcurt, i) for (i,load) in pm.ref[:nw][n][:load])
        +
        sum(load["cost_investment"]*_PM.var(pm, n, :z_flex, i) for (i,load) in pm.ref[:nw][n][:load])
        )
    end
    if is_contingency
        if n ∉ [parse(Int, i) for i in keys(pm.ref[:contingency]["0"])]
            inv_cost += sum(load["cost_voll"]*_PM.var(pm, n, :pinter, i) for (i,load) in pm.ref[:nw][n][:load])
        end
    end
    return inv_cost
end

function calc_convdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :convdc_ne)
        convdc_ne = _PM.ref(pm, n, :convdc_ne)
        if !isempty(convdc_ne)    
            cost = sum(conv["cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in convdc_ne)
            if add_co2_cost
                cost += sum(conv["co2_cost"]*_PM.var(pm, n, :conv_ne, i) for (i,conv) in convdc_ne)
            end
        end
    end
    return cost
end

function calc_ne_branch_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :ne_branch)
        ne_branch = _PM.ref(pm, n, :ne_branch)
        if !isempty(ne_branch)
            cost = sum(branch["construction_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in ne_branch)
            if add_co2_cost
                cost += sum(branch["co2_cost"]*_PM.var(pm, n, :branch_ne, i) for (i,branch) in ne_branch)
            end
        end
    end
    return cost
end

function calc_branchdc_ne_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :branchdc_ne)
        branchdc_ne = _PM.ref(pm, n, :branchdc_ne)
        if !isempty(branchdc_ne)
            cost = sum(branch["cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in branchdc_ne)
            if add_co2_cost
                cost += sum(branch["co2_cost"]*_PM.var(pm, n, :branchdc_ne, i) for (i,branch) in branchdc_ne)
            end
        end
    end
    return cost
end

function calc_ne_storage_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    cost = 0.0
    if haskey(_PM.ref(pm, n), :ne_storage)
        ne_storage = _PM.ref(pm, n, :ne_storage)
        if !isempty(ne_storage)
            cost = sum((storage["eq_cost"] + storage["inst_cost"])*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in ne_storage)
            if add_co2_cost
                cost += sum(storage["co2_cost"]*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in ne_storage)
            end
        end
    end
    return cost
end

function calc_load_cost(pm::_PM.AbstractPowerModel, n::Int, add_co2_cost::Bool)
    load = _PM.ref(pm, n, :load)
    cost = sum(
                l["cost_shift_up"]*_PM.var(pm, n, :pshift_up, i)
                +
                l["cost_shift_down"]*_PM.var(pm, n, :pshift_down, i)
                +
                l["cost_reduction"]*_PM.var(pm, n, :pnce, i)
                +
                l["cost_curtailment"]*_PM.var(pm, n, :pcurt, i)
                +
                l["cost_investment"]*_PM.var(pm, n, :z_flex, i)
            for (i,l) in load)
    if add_co2_cost
        cost += sum(l["co2_cost"]*_PM.var(pm, n, :z_flex, i) for (i,l) in load)
    end
    return cost
end
