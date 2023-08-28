import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
import Ipopt
import Memento
import JuMP
import Gurobi  # needs startvalues for all variables!
import Juniper

file = normpath(@__DIR__,"../../test/data/case67/case67.m")
file_2030 = normpath(@__DIR__,"../../test/data/case67/case67_tnep_2030.m")
file_2040 = normpath(@__DIR__,"../../test/data/case67/case67_tnep_2040.m")
file_2050 = normpath(@__DIR__,"../../test/data/case67/case67_tnep_2050.m")

ipopt = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer)
juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer)

s = Dict("conv_losses_mp" => true)

resultAC = _PMACDC.run_acdcopf(file, _PM.ACPPowerModel, ipopt; setting = s)
resultDC = _PMACDC.run_acdcopf(file, _PM.DCPPowerModel, gurobi; setting = s)

result2030= _PMACDC.run_tnepopf(file_2030, _PM.DCPPowerModel, gurobi, setting = s)
result2040= _PMACDC.run_tnepopf(file_2040, _PM.DCPPowerModel, gurobi, setting = s)
result2050= _PMACDC.run_tnepopf(file_2050, _PM.DCPPowerModel, gurobi, setting = s)