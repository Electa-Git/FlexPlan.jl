import FlexPlan; const _FP = FlexPlan
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import PowerModels; const _PM = PowerModels
import InfrastructureModels; const _IM = InfrastructureModels
using JuMP
using Memento

include(normpath(@__DIR__,"..","test","io","create_profile.jl"))
include(normpath(@__DIR__,"..","test","io","multiple_years.jl"))
include(normpath(@__DIR__,"..","test","io","load_case.jl"))

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
Memento.setlevel!(Memento.getlogger(PowerModelsACDC), "error")
Memento.setlevel!(Memento.getlogger(PowerModels), "error")

using Ipopt
using SCS
using Cbc
using Juniper

using Test


ipopt_solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
scs_solver = JuMP.optimizer_with_attributes(SCS.Optimizer, "verbose" => 0)
cbc = JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "threads"=>Threads.nthreads())
juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver" => ipopt_solver, "mip_solver" => cbc, "time_limit" => 7200)

@testset "FlexPlan" begin

    # FlexPlan components
    include("dimensions.jl")
    include("io.jl")

    # Models
    include("bfarad.jl")

    # Network components
    include("gen.jl")
    include("flex_demand.jl")
    include("storage.jl")

    # Problems
    include("prob.jl")

end;
