# Single-network containing only fixed data (i.e. data that does not depend on year), method without candidates
function nw(source::AbstractDict, lookup::AbstractDict, y::Int; oltc::Bool, scale_gen::Real)
    target = Dict{String,Any}(
        "branch"       => Dict{String,Any}(),
        "branchdc"     => Dict{String,Any}(),
        "bus"          => Dict{String,Any}(),
        "busdc"        => Dict{String,Any}(),
        "convdc"       => Dict{String,Any}(),
        "dcline"       => Dict{String,Any}(),
        "gen"          => Dict{String,Any}(),
        "load"         => Dict{String,Any}(),
        "shunt"        => Dict{String,Any}(),
        "storage"      => Dict{String,Any}(),
        "switch"       => Dict{String,Any}(),
        "dcpol"        => 2, # Assumption: DC grid has 2 poles.
        "per_unit"     => true,
        "time_elapsed" => 1.0, # Assumption: each period lasts 1 hour.
    )
    if haskey(source["genericParameters"], "basePower")
        target["baseMVA"] = source["genericParameters"]["basePower"]
    else
        Memento.error(_LOGGER, "\"genericParameters.basePower\" is a required parameter.")
    end

    # AC branches are split between `acBranches` and `transformers` dicts in JSON files
    branch_path = ["gridModelInputFile", "acBranches"]
    for comp in walkpath(source, branch_path)
        index     = lookup["acBranches"][comp["id"]]
        source_id = push!(copy(branch_path), comp["id"])
        f_bus     = lookup["acBuses"][comp["acBusOrigin"]]
        t_bus     = lookup["acBuses"][comp["acBusExtremity"]]
        target["branch"]["$index"] = make_branch(comp, index, source_id, f_bus, t_bus, y; transformer=false)
    end
    branch_path = ["gridModelInputFile", "transformers"]
    for comp in walkpath(source, branch_path)
        index     = lookup["transformers"][comp["id"]]
        source_id = push!(copy(branch_path), comp["id"])
        f_bus     = lookup["acBuses"][comp["acBusOrigin"]]
        t_bus     = lookup["acBuses"][comp["acBusExtremity"]]
        target["branch"]["$index"] = make_branch(comp, index, source_id, f_bus, t_bus, y; transformer=true, oltc)
    end

    branchdc_path = ["gridModelInputFile", "dcBranches"]
    for comp in walkpath(source, branchdc_path)
        index     = lookup["dcBranches"][comp["id"]]
        source_id = push!(copy(branchdc_path), comp["id"])
        fbusdc    = lookup["dcBuses"][comp["dcBusOrigin"]]
        tbusdc    = lookup["dcBuses"][comp["dcBusExtremity"]]
        target["branchdc"]["$index"] = make_branchdc(comp, index, source_id, fbusdc, tbusdc, y)
    end

    bus_path = ["gridModelInputFile", "acBuses"]
    for comp in walkpath(source, bus_path)
        index     = lookup["acBuses"][comp["id"]]
        source_id = push!(copy(bus_path), comp["id"])
        target["bus"]["$index"] = make_bus(comp, index, source_id)
    end

    busdc_path = ["gridModelInputFile", "dcBuses"]
    for comp in walkpath(source, busdc_path)
        index     = lookup["dcBuses"][comp["id"]]
        source_id = push!(copy(busdc_path), comp["id"])
        target["busdc"]["$index"] = make_busdc(comp, index, source_id)
    end

    convdc_path = ["gridModelInputFile", "converters"]
    for comp in walkpath(source, convdc_path)
        index     = lookup["converters"][comp["id"]]
        source_id = push!(copy(convdc_path), comp["id"])
        busac     = lookup["acBuses"][comp["acBusConnected"]]
        busdc     = lookup["dcBuses"][comp["dcBusConnected"]]
        typeac    = walkpath(source, bus_path)[busac]["busType"]
        target["convdc"]["$index"] = make_convdc(comp, index, source_id, busac, busdc, typeac, y)
    end

    gen_path = ["gridModelInputFile", "generators"]
    for comp in walkpath(source, gen_path)
        index     = lookup["generators"][comp["id"]]
        source_id = push!(copy(gen_path), comp["id"])
        gen_bus   = lookup["acBuses"][comp["acBusConnected"]]
        target["gen"]["$index"] = make_gen(comp, index, source_id, gen_bus, y; scale_gen)
    end

    load_path = ["gridModelInputFile", "loads"]
    for comp in walkpath(source, load_path)
        index     = lookup["loads"][comp["id"]]
        source_id = push!(copy(load_path), comp["id"])
        load_bus  = lookup["acBuses"][comp["acBusConnected"]]
        target["load"]["$index"] = make_load(comp, index, source_id, load_bus, y)
    end

    storage_path = ["gridModelInputFile", "storage"]
    for comp in walkpath(source, storage_path)
        index       = lookup["storage"][comp["id"]]
        source_id   = push!(copy(storage_path), comp["id"])
        storage_bus = lookup["acBuses"][comp["acBusConnected"]]
        target["storage"]["$index"] = make_storage(comp, index, source_id, storage_bus, y)
    end

    return target
end

# Single-network containing only fixed data (i.e. data that does not depend on year), method with candidates
function nw(source::AbstractDict, lookup::AbstractDict, cand_availability::AbstractDict, y::Int; oltc::Bool, scale_gen::Real)

    target = nw(source, lookup, y; oltc, scale_gen)
    target["branchdc_ne"] = Dict{String,Any}()
    target["busdc_ne"]    = Dict{String,Any}()
    target["convdc_ne"]   = Dict{String,Any}()
    target["ne_branch"]   = Dict{String,Any}()
    target["ne_storage"]  = Dict{String,Any}()

    bus_path = ["gridModelInputFile", "acBuses"] # Needed by convdc_ne

    ne_branch_path = ["candidatesInputFile", "acBranches"]
    for cand in walkpath(source, ne_branch_path)
        comp = cand["acBranch"]
        if cand_availability["acBranches"][comp["id"]][y]
            index     = lookup["cand_acBranches"][comp["id"]]
            source_id = push!(copy(ne_branch_path), comp["id"])
            f_bus     = lookup["acBuses"][comp["acBusOrigin"]]
            t_bus     = lookup["acBuses"][comp["acBusExtremity"]]
            t = make_branch(comp, index, source_id, f_bus, t_bus, y; transformer=false)
            t["construction_cost"] = cand["invCost"][y]
            t["lifetime"]          = cand["lifetime"]
            t["replace"]           = replace(cand, comp["id"], lookup["acBranches"]) # Assumption: specified id is that of the branch that connects the same buses.
            target["ne_branch"]["$index"] = t
        end
    end
    ne_branch_path = ["candidatesInputFile", "transformers"]
    for cand in walkpath(source, ne_branch_path)
        comp = cand["acBranch"]
        if cand_availability["transformers"][comp["id"]][y]
            index     = lookup["cand_transformers"][comp["id"]]
            source_id = push!(copy(ne_branch_path), comp["id"])
            f_bus     = lookup["acBuses"][comp["acBusOrigin"]]
            t_bus     = lookup["acBuses"][comp["acBusExtremity"]]
            t = make_branch(comp, index, source_id, f_bus, t_bus, y; transformer=true, oltc)
            t["construction_cost"] = cand["invCost"][y]
            t["lifetime"]          = cand["lifetime"]
            t["replace"]           = replace(cand, comp["id"], lookup["transformers"]) # Assumption: specified id is that of the branch that connects the same buses.
            target["ne_branch"]["$index"] = t
        end
    end

    branchdc_ne_path = ["candidatesInputFile", "dcBranches"]
    for cand in walkpath(source, branchdc_ne_path)
        comp = cand["dcBranch"]
        if cand_availability["dcBranches"][comp["id"]][y]
            index     = lookup["cand_dcBranches"][comp["id"]]
            source_id = push!(copy(branchdc_ne_path), comp["id"])
            fbusdc    = lookup["dcBuses"][comp["dcBusOrigin"]]
            tbusdc    = lookup["dcBuses"][comp["dcBusExtremity"]]
            t = make_branchdc(comp, index, source_id, fbusdc, tbusdc, y)
            t["cost"]     = cand["invCost"][y]
            t["lifetime"] = cand["lifetime"]
            target["branchdc_ne"]["$index"] = t
        end
    end

    convdc_ne_path = ["candidatesInputFile", "converters"]
    for cand in walkpath(source, convdc_ne_path)
        comp = cand["converter"]
        if cand_availability["converters"][comp["id"]][y]
            index     = lookup["cand_converters"][comp["id"]]
            source_id = push!(copy(convdc_ne_path), comp["id"])
            busac     = lookup["acBuses"][comp["acBusConnected"]]
            busdc     = lookup["dcBuses"][comp["dcBusConnected"]]
            typeac    = walkpath(source, bus_path)[busac]["busType"]
            t = make_convdc(comp, index, source_id, busac, busdc, typeac, y)
            t["cost"]     = cand["invCost"][y]
            t["lifetime"] = cand["lifetime"]
            target["convdc_ne"]["$index"] = t
        end
    end

    load_path = ["candidatesInputFile", "flexibleLoads"]
    for cand in walkpath(source, load_path)
        comp = cand["load"]
        if cand_availability["loads"][comp["id"]][y]
            index     = lookup["loads"][comp["id"]] # Candidate loads have same ids as existing loads
            source_id = push!(copy(load_path), comp["id"])
            load_bus  = lookup["acBuses"][comp["acBusConnected"]]
            t = make_load(comp, index, source_id, load_bus, y)
            t["cost_inv"] = cand["invCost"][y]
            t["lifetime"] = cand["lifetime"]
            target["load"]["$index"] = t # The candidate load replaces the existing load that has the same id and is assumed to have the same parameters as that existing load.
        end
    end

    ne_storage_path = ["candidatesInputFile", "storage"]
    for cand in walkpath(source, ne_storage_path)
        comp = cand["storage"]
        if cand_availability["storage"][comp["id"]][y]
            index     = lookup["cand_storage"][comp["id"]]
            source_id = push!(copy(ne_storage_path), comp["id"])
            storage_bus = lookup["acBuses"][comp["acBusConnected"]]
            t = make_storage(comp, index, source_id, storage_bus, y)
            t["eq_cost"]   = cand["invCost"][y]
            t["inst_cost"] = 0.0
            t["lifetime"]  = cand["lifetime"]
            target["ne_storage"]["$index"] = t
        end
    end

    return target
end

function walkpath(node::AbstractDict, path::Vector{String})
    for key in path
        node = node[key]
    end
    return node
end

function optional_value(target::AbstractDict, target_key::String, source::AbstractDict, source_key::String)
    if haskey(source, source_key)
        target[target_key] = source[source_key]
    end
end

function optional_value(target::AbstractDict, target_key::String, source::AbstractDict, source_key::String, y::Int)
    if haskey(source, source_key) && !isempty(source[source_key])
        target[target_key] = source[source_key][y]
    end
end

function replace(cand::AbstractDict, id::String, comp_lookup::AbstractDict)
    if haskey(cand, "replace")
        if haskey(comp_lookup, cand["replace"])
            # FlexPlan.jl only supports replacement of the only branch that connects the same buses as the candidate.
            # That branch will be replaced, regardless of which branch is specified by `cand["replace"]`.
            return true
        else
            Memento.warn(_LOGGER, "Cannot set \"$id\" to replace \"" * cand["replace"] * "\" because \"" * cand["replace"] * "\" does not exist.")
            return false
        end
    else
        return false
    end
end

function make_branch(source::AbstractDict, index::Int, source_id::Vector{String}, f_bus::Int, t_bus::Int, y::Int; transformer::Bool, oltc::Bool=false)
    target = Dict{String,Any}(
        "index"       => index,
        "source_id"   => source_id,
        "f_bus"       => f_bus,
        "t_bus"       => t_bus,
        "br_status"   => 1, # Assumption: all branches defined in JSON file are in service.
        "transformer" => transformer,
        "b_fr"        => 0.0, # Assumption: all branches defined in JSON file have zero shunt susceptance.
        "b_to"        => 0.0, # Assumption: all branches defined in JSON file have zero shunt susceptance.
        "g_fr"        => 0.0, # Assumption: all branches defined in JSON file have zero shunt conductance.
        "g_to"        => 0.0, # Assumption: all branches defined in JSON file have zero shunt conductance.
        "rate_a"      => source["ratedApparentPower"][y],
        "rate_c"      => source["emergencyRating"],
        "tap"         => source["voltageTapRatio"],
        "shift"       => 0.0, # Assumption: all branches defined in JSON file have zero shift.
        "angmin"      => source["minAngleDifference"],
        "angmax"      => source["maxAngleDifference"],
    )
    optional_value(target, "br_r", source, "resistance")
    if source["isTransmission"]
        target["br_r"] = 0.0
        target["br_x"] = 1/source["susceptance"]
    else
        target["br_r"] = source["resistance"]
        target["br_x"] = source["reactance"]
        if transformer && oltc
            target["tm_max"] = 1.1
            target["tm_min"] = 0.9
        end
    end
    return target
end

function make_branchdc(source::AbstractDict, index::Int, source_id::Vector{String}, fbusdc::Int, tbusdc::Int, y::Int)
    target = Dict{String,Any}(
        "index"     => index,
        "source_id" => source_id,
        "fbusdc"    => fbusdc,
        "tbusdc"    => tbusdc,
        "status"    => 1, # Assumption: all branches defined in JSON file are in service.
        "rateA"     => source["ratedActivePower"][y],
        "rateC"     => source["emergencyRating"],
        "r"         => 0.0, # Assumption: zero resistance (the parameter is required by PowerModelsACDC but unused in lossless models).
    )
    return target
end

function make_bus(source::AbstractDict, index::Int, source_id::Vector{String})
    target = Dict{String,Any}(
        "index"     => index,
        "bus_i"     => index,
        "source_id" => source_id,
        "vm"        => source["nominalVoltageMagnitude"],
    )
    optional_value(target, "bus_type", source, "busType")
    if haskey(target, "bus_type") && target["bus_type"] == 3
        target["va"] = 0.0 # Set voltage angle of reference bus to 0.0
    end
    optional_value(target, "base_kv",  source, "baseVoltage")
    optional_value(target, "vmax",     source, "maxVoltageMagnitude")
    optional_value(target, "vmin",     source, "minVoltageMagnitude")
    if haskey(source, "location")
        target["lat"] = source["location"][1]
        target["lon"] = source["location"][2]
    end
    return target
end

function make_busdc(source::AbstractDict, index::Int, source_id::Vector{String})
    target = Dict{String,Any}(
        "index"     => index,
        "busdc_i"   => index,
        "source_id" => source_id,
        "Vdc"       => source["nominalVoltageMagnitude"],
        "Vdcmin"    => 0.9, # Assumption: minimum DC voltage is 0.9 p.u. for every DC bus
        "Vdcmax"    => 1.1, # Assumption: maximum DC voltage is 1.1 p.u. for every DC bus
        "Pdc"       => 0.0, # Assumption: power withdrawn from DC bus is 0.0 p.u.
    )
    optional_value(target, "basekVdc", source, "baseVoltage")
    return target
end

function make_convdc(source::AbstractDict, index::Int, source_id::Vector{String}, busac::Int, busdc::Int, typeac::Int, y::Int)
    target = Dict{String,Any}(
        "index"       => index,
        "source_id"   => source_id,
        "status"      => 1, # Assumption: all converters defined in JSON file are in service.
        "busac_i"     => busac,
        "busdc_i"     => busdc,
        "type_ac"     => typeac,
        "type_dc"     => 3, # Assumption: all converters defined in JSON file have DC droop.
        "Vmmin"       => 0.9, # Required by PowerModelsACDC, but not relevant, since we use an approximation where voltage magnitude is 1.0 p.u. at each AC transmission network bus
        "Vmmax"       => 1.1, # Required by PowerModelsACDC, but not relevant, since we use an approximation where voltage magnitude is 1.0 p.u. at each AC transmission network bus
        "Pacrated"    => source["ratedActivePowerAC"][y],
        "Pacmin"      => -source["ratedActivePowerAC"][y],
        "Pacmax"      => source["ratedActivePowerAC"][y],
        "Qacrated"    => 0.0, # Required by PowerModelsACDC, but unused in active power only models.
        "LossA"       => source["auxiliaryLosses"][y],
        "LossB"       => source["linearLosses"][y],
        "LossCinv"    => 0.0,
        "Imax"        => 0.0, # Required by PowerModelsACDC, but unused in lossless models.
        "transformer" => false, # Assumption: the converter is not a transformer.
        "tm"          => 0.0, # Required by PowerModelsACDC, but unused, provided that the converter is not a transformer.
        "rtf"         => 0.0, # Required by PowerModelsACDC, but unused, provided that the converter is not a transformer.
        "xtf"         => 0.0, # Required by PowerModelsACDC, but unused, provided that the converter is not a transformer.
        "reactor"     => false, # Assumption: the converter is not a reactor.
        "rc"          => 0.0, # Required by PowerModelsACDC, but unused, provided that the converter is not a reactor.
        "xc"          => 0.0, # Required by PowerModelsACDC, but unused, provided that the converter is not a reactor.
        "filter"      => false, # Required by PowerModelsACDC, but unused, provided that the model is lossless.
        "bf"          => 0.0, # Required by PowerModelsACDC, but unused, provided that the model is lossless.
        "islcc"       => 0.0, # Required by PowerModelsACDC, but unused, provided that the model is DC.
    )
    return target
end

function make_gen(source::AbstractDict, index::Int, source_id::Vector{String}, gen_bus::Int, y::Int; scale_gen::Real)
    target = Dict{String,Any}(
        "index"        => index,
        "source_id"    => source_id,
        "gen_status"   => 1, # Assumption: all generators defined in JSON file are in service.
        "gen_bus"      => gen_bus,
        "qmin"         => source["minReactivePower"][y],
        "qmax"         => source["maxReactivePower"][y],
        "vg"           => 1.0,
        "model"        => 2, # Polynomial cost model
        "ncost"        => 2, # 2 cost coefficients: c1 and c0
        "cost"         => [source["generationCosts"][y], 0.0], # [c1, c0]
    )
    pmin = source["minActivePower"][y]
    pmax = source["maxActivePower"][y]
    target["pmax"] = scale_gen * pmax
    if pmin == pmax # Non-dispatchable generators are characterized in JSON file by having coincident power bounds
        target["dispatchable"] = false
        target["pmin"] = 0.0 # Must be zero to allow for curtailment
        target["cost_curt"] = source["curtailmentCosts"][y]
    else
        target["dispatchable"] = true
        target["pmin"] = scale_gen * pmin
    end
    return target
end

function make_load(source::AbstractDict, index::Int, source_id::Vector{String}, load_bus::Int, y::Int)
    target = Dict{String,Any}(
        "index"     => index,
        "source_id" => source_id,
        "status"    => 1, # Assumption: all loads defined in JSON file are in service.
        "load_bus"  => load_bus,
        "flex"      => get(source, "isFlexible", false),
    )
    if haskey(source, "powerFactor")
        target["pf_angle"] = acos(source["powerFactor"])
    end
    optional_value(target, "pred_rel_max",        source, "superiorBoundNCP",        y)
    optional_value(target, "ered_rel_max",        source, "maxEnergyNotConsumed",    y)
    optional_value(target, "pshift_up_rel_max",   source, "superiorBoundUDS",        y)
    optional_value(target, "pshift_down_rel_max", source, "superiorBoundDDS",        y)
    optional_value(target, "tshift_up",           source, "gracePeriodUDS",          y)
    optional_value(target, "tshift_down",         source, "gracePeriodDDS",          y)
    optional_value(target, "eshift_rel_max",      source, "maxEnergyShifted",        y)
    optional_value(target, "cost_curt",           source, "valueOfLossLoad",         y)
    optional_value(target, "cost_red",            source, "compensationConsumeLess", y)
    optional_value(target, "cost_shift",          source, "compensationDemandShift", y)
    return target
end

function make_storage(source::AbstractDict, index::Int, source_id::Vector{String}, storage_bus::Int, y::Int)
    target = Dict{String,Any}(
        "index"                 => index,
        "source_id"             => source_id,
        "status"                => 1, # Assumption: all generators defined in JSON file are in service.
        "storage_bus"           => storage_bus,
        "energy_rating"         => source["maxEnergy"][y],
        "charge_rating"         => source["maxAbsActivePower"][y],
        "discharge_rating"      => source["maxInjActivePower"][y],
        "charge_efficiency"     => source["absEfficiency"][y],
        "discharge_efficiency"  => source["injEfficiency"][y],
        "qmin"                  => source["minReactivePowerExchange"][y],
        "qmax"                  => source["maxReactivePowerExchange"][y],
        "self_discharge_rate"   => source["selfDischargeRate"][y],
        "r"                     => 0.0, # JSON API does not support `r`. Neither Flexplan.jl does (in lossless models), however a value is required by the constraint templates `_PM.constraint_storage_losses` and `_FP.constraint_storage_losses_ne`.
        "x"                     => 0.0, # JSON API does not support `x`. Neither Flexplan.jl does (in lossless models), however a value is required by the constraint templates `_PM.constraint_storage_losses` and `_FP.constraint_storage_losses_ne`.
        "p_loss"                => 0.0, # JSON API does not support `p_loss`. Neither Flexplan.jl does, however a value is required by the constraint templates `_PM.constraint_storage_losses` and `_FP.constraint_storage_losses_ne`.
        "q_loss"                => 0.0, # JSON API does not support `q_loss`. Neither Flexplan.jl does, however a value is required by the constraint templates `_PM.constraint_storage_losses` and `_FP.constraint_storage_losses_ne`.
    )
    # JSON API does not support storage thermal rating, but a value is required by
    # `FlexPlan.constraint_storage_thermal_limit`. The following expression prevents it from
    # limiting active or reactive power, even in the case of octagonal approximation of
    # apparent power.
    target["thermal_rating"] = 2 * max(target["charge_rating"], target["discharge_rating"], target["qmax"], -target["qmin"])
    optional_value(target, "max_energy_absorption", source, "maxEnergyYear", y)
    return target
end
