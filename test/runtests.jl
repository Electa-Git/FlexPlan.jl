import FlexPlan as _FP
import PowerModelsACDC as _PMACDC
import PowerModels as _PM
import InfrastructureModels as _IM
using JuMP
using Memento

include(normpath(@__DIR__,"..","test","io","load_case.jl"))

# Suppress warnings during testing.
Memento.setlevel!(Memento.getlogger(_IM), "error")
Memento.setlevel!(Memento.getlogger(_PMACDC), "error")
Memento.setlevel!(Memento.getlogger(_PM), "error")

using Test
import HiGHS

milp_optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)


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

    # Exported symbols
    include("export.jl")

end;
