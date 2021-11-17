# Dimensions

All the optimization problems modeled in FlexPlan are multiperiod and make use of the following _dimensions_:

- `hour`. The finest time granularity that can be represented in a model: during an hour, each continuous variables has a constant value.
- `year`. An investment period: different investment decisions can be made in different years,
- `scenario`. One of the different possible sets of values related to renewable generation and consumption data.

These dimensions must be defined in each model by calling the function `add_dimension!` on single-period data dictionaries. The `add_dimension!` function takes the name of the dimension as input in form of a key, as well as either integer values, e.g., for number of hours or years, or a dictionary, e.g., containing multiple scenarios. In the case of scenario input, probabilities and other meta data can be added. An example can be found below:

```julia
_FP.add_dimension!(data, :hour, number_of_hours) # add dimension, e.g. number of hours
_FP.add_dimension!(data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)), metadata = Dict{String,Any}("mc"=>true)) # add dimension, e.g., number of scenarios
_FP.add_dimension!(t_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1)) # Add dimension of years, using cost scaling factors in metadata
```
