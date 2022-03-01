module TDDecoupling

export surrogate_model!

using ..FlexPlan
const _FP = FlexPlan
import ..FlexPlan: _LOGGER

import PowerModels
const _PM = PowerModels

import JuMP
import Memento

include("base.jl")
include("probe_flexibility.jl")
include("surrogate_model.jl")

end
