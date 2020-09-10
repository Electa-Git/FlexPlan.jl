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
# import InfrastructureModels: ids, ref, var, con, sol, nw_ids, nws, optimize_model!, @im_fields
const _IM = InfrastructureModels

import JuMP: with_optimizer
export with_optimizer

# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
# NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.
__init__() = Memento.register(_LOGGER)


include("prob/flexible_tnep.jl")
include("prob/storage_tnep.jl")

include("io/profile_data.jl")

include("core/flexible_demand.jl")
include("core/storage.jl")
include("core/objective.jl")
include("core/model_references.jl")
include("core/shared_constraints.jl")
end
