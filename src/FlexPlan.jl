module FlexPlan


## Imports

import Memento
import JuMP
import InfrastructureModels as _IM
import PowerModels as _PM
import PowerModelsACDC as _PMACDC


## Memento settings

# Create our module level logger (this will get precompiled)
const _LOGGER = Memento.getlogger(@__MODULE__)

# Register the module level logger at runtime so that folks can access the logger via `getlogger(FlexPlan)`
# NOTE: If this line is not included then the precompiled `FlexPlan._LOGGER` won't be registered at runtime.
__init__() = Memento.register(_LOGGER)


## Includes

include("prob/storage_tnep.jl")
include("prob/flexible_tnep.jl")
include("prob/stochastic_flexible_tnep.jl")
include("prob/simple_stochastic_flexible_tnep.jl")

include("io/parse.jl")
include("io/scale.jl")
include("io/time_series.jl")
include("io/multinetwork.jl")
include("io/plot_geo_data.jl")

include("core/types.jl")
include("core/dimensions.jl")
include("core/variable.jl")
include("core/variableconv.jl")
include("core/variabledcgrid.jl")
include("core/gen.jl")
include("core/flexible_demand.jl")
include("core/storage.jl")
include("core/objective.jl")
include("core/ref_extension.jl")
include("core/constraint_template.jl")
include("core/constraint.jl")
include("core/line_replacement.jl")
include("core/distribution.jl")
include("core/td_coupling.jl")
include("core/solution.jl")

include("form/bf.jl")
include("form/bfarad.jl")
include("formconv/dcp.jl")


## Submodules

include("json_converter/json_converter.jl")
using .JSONConverter

include("benders/benders.jl")
using .Benders

include("td_decoupling/td_decoupling.jl")
using .TDDecoupling


## Exports

# FlexPlan exports everything except internal symbols, which are defined as those whose name
# starts with an underscore. If you don't want all of these symbols in your environment,
# then use `import FlexPlan` instead of `using FlexPlan`.

# Do not add FlexPlan-defined symbols to this exclude list. Instead, rename them with an
# underscore.
const _EXCLUDE_SYMBOLS = [Symbol(@__MODULE__), :eval, :include]

for sym in names(@__MODULE__, all=true)
    sym_string = string(sym)
    if sym in _EXCLUDE_SYMBOLS || startswith(sym_string, "_") || startswith(sym_string, "@_")
        continue
    end
    if !(Base.isidentifier(sym) || (startswith(sym_string, "@") &&
         Base.isidentifier(sym_string[2:end])))
       continue
    end
    #println("$(sym)")
    @eval export $sym
end

# The following items are also exported for user-friendlyness when calling `using FlexPlan`,
# so that users do not need to import JuMP to use a solver with FlexPlan.
import JuMP: optimizer_with_attributes
export optimizer_with_attributes

import JuMP: TerminationStatusCode
export TerminationStatusCode

import JuMP: ResultStatusCode
export ResultStatusCode

for status_code_enum in [TerminationStatusCode, ResultStatusCode]
    for status_code in instances(status_code_enum)
        @eval import JuMP: $(Symbol(status_code))
        @eval export $(Symbol(status_code))
    end
end


end
