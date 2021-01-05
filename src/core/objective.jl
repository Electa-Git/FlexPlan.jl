##################################################################
##################### Objective with candidate storage
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
            if haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"] == true
                gen_cost[(n,i)] = gen_cost[(n,i)] + gen["emission_factor"] * pg * pm.ref[:emission_cost]
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
            sum((storage["eq_cost"] + storage["inst_cost"] + storage["co2_cost"])*_PM.var(pm, n, :z_strg_ne, i) for (i,storage) in nw_ref[:ne_storage])
            +
            sum( gen_cost[(n,i)] for (i,gen) in nw_ref[:gen] )
            for (n, nw_ref) in _PM.nws(pm)
                )
    )
end

####################################################################################
##################### Objective Objective with candidate storage and flexible demand
####################################################################################
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
            if haskey(pm.setting, "add_co2_cost") && pm.setting["add_co2_cost"] == true
                gen_cost[(n,i)] = gen_cost[(n,i)] + gen["emission_factor"] * pg * pm.ref[:co2_emission_cost]
            end
        end
    end

    return JuMP.@objective(pm.model, Min,
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in pm.ref[:nw][n][:gen] ) + calculate_inv_cost(pm, n)
            for (n, nw_ref) in _PM.nws(pm)
                )
    )
end

##########################################################################
##################### Stocjastic objective with storage & flex candidates
##########################################################################
function objective_stoch_flex(pm::_PM.AbstractPowerModel)
    gen_cost = Dict()
    for (s, scenario) in pm.ref[:scenario]
        for (sc, n) in scenario
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
    sum(pm.ref[:scenario_prob][s] * 
        sum(
            sum( gen_cost[(n,i)] for (i,gen) in pm.ref[:nw][n][:gen]) + calculate_inv_cost(pm, n)
            for (sc, n) in scenario
                ) 
        for (s, scenario) in pm.ref[:scenario]
            )
    )
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
            sum(gen_cost[(n,i)] for (i,gen) in pm.ref[:nw][n][:gen]) + calculate_inv_cost(pm, n, is_reliability=true)
            for (sc, n) in contingency # All times in a contingency scenario
                ) 
        for (s, contingency) in pm.ref[:contingency] # All contingency
            )
    )
end

function calculate_inv_cost(pm::_PM.AbstractPowerModel, n::Int; is_reliability::Bool=false)
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
    if is_reliability
        inv_cost += sum(load["cost_voll"]*_PM.var(pm, n, :pinter, i) for (i,load) in pm.ref[:nw][n][:load])
    end
    return inv_cost
end

