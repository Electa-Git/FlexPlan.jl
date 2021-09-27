# Dimensions

All the optimization problems modeled in FlexPlan are multiperiod and make use of the following _dimensions_:

- `hour`. The finest time granularity that can be represented in a model: during an hour, each continuous variables has a constant value.
- `year`. An investment period: different investment decisions can be made in different years,
- `scenario`. One of the different possible sets of values related to renewable generation and consumption data.

These dimensions must be defined in each model by calling the function `add_dimension!` on single-period data dictionaries.
