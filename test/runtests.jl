import FlexPlan as _FP
import PowerModelsACDC as _PMACDC
import PowerModels as _PM
import InfrastructureModels as _IM
using JuMP
using Memento

include(normpath(@__DIR__,"..","test","io","create_profile.jl"))
include(normpath(@__DIR__,"..","test","io","multiple_years.jl"))
include(normpath(@__DIR__,"..","test","io","load_case.jl"))

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(_IM), "error")
Memento.setlevel!(Memento.getlogger(_PMACDC), "error")
Memento.setlevel!(Memento.getlogger(_PM), "error")

using Ipopt
using SCS
using Cbc
using Juniper
import HiGHS

using Test


ipopt_solver = JuMP.optimizer_with_attributes(Ipopt.Optimizer, "tol" => 1e-6, "print_level" => 0)
scs_solver = JuMP.optimizer_with_attributes(SCS.Optimizer, "verbose" => 0)

# Cbc cannot be used on Windows with multiple threads: <https://github.com/jump-dev/Cbc.jl/issues/186>
# The `threads` argument is already disabled on Windows since Cbc v1.0.0: <https://github.com/jump-dev/Cbc.jl/pull/192>
# We cannot use Cbc v1.0.0 at the moment because it requires MathOptInterface v1 and we require MathOptInterface v0.10.9.
# Removal of MathOptInterface from FlexPlan.jl dependencies is to be done: <https://github.com/Electa-Git/FlexPlan.jl/issues/121#issue-1158572058>
if Sys.iswindows()
    cbc = JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0)
else
    cbc = JuMP.optimizer_with_attributes(Cbc.Optimizer, "logLevel" => 0, "threads"=>Threads.nthreads())
end

juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer, "nl_solver" => ipopt_solver, "mip_solver" => cbc, "time_limit" => 7200)

highs = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false)

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

    # Decompositions
    include("td_decoupling.jl")

end;
