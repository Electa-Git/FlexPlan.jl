module JSONConverter

export convert_JSON

using ..FlexPlan
const _FP = FlexPlan
import ..FlexPlan: _LOGGER

import JSON
import Memento

include("base.jl")
include("nw.jl")
include("time_series.jl")
include("singular_data.jl")

end
