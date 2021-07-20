isdefined(Base, :__precompile__) && __precompile__()

module FlexPlan

# import Compat
import JuMP
import Memento
import PowerModels
import PowerModelsACDC
const _PM = PowerModels
const _PMACDC = PowerModelsACDC
import InfrastructureModels
#import InfrastructureModels: ids, ref, var, con, sol, nw_ids, nws, optimize_model!, @im_fields
const _IM = InfrastructureModels
const _MOI = _IM._MOI # MathOptInterface

import JuMP: with_optimizer, optimizer_with_attributes
export with_optimizer, optimizer_with_attributes

using Printf

# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
__init__() = Memento.register(_LOGGER)


include("prob/dist.jl")
include("prob/flexible_tnep.jl")
include("prob/stochastic_flexible_tnep.jl")
include("prob/storage_tnep.jl")
include("prob/reliability_tnep.jl")

include("io/common.jl")
include("io/multinetwork.jl")
include("io/plot_geo_data.jl")
include("io/profile_data.jl")

include("core/types.jl")
include("core/variable.jl")
include("core/variableconv.jl")
include("core/variabledcgrid.jl")
include("core/flexible_demand.jl")
include("core/storage.jl")
include("core/objective.jl")
include("core/reliability.jl")
include("core/model_references.jl")
include("core/shared_constraints.jl")
include("core/line_replacement.jl")
include("core/distribution.jl")
include("core/t-d_coupling.jl")
include("core/benders_decomposition.jl")

include("form/bf.jl")
include("form/bfarad.jl")
include("formconv/dcp.jl")
end
