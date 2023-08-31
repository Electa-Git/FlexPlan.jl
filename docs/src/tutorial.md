# Tutorial

This page shows how to define and solve network planning problems using FlexPlan.

!!! tip
    Before following this tutorial you might want to have a look at some [examples](@ref Examples).

## 1. Import packages

FlexPlan builds on [PowerModels](https://github.com/lanl-ansi/PowerModels.jl) and [PowerModelsACDC](https://github.com/Electa-Git/PowerModelsACDC.jl) packages.
You can declare the packages as follows, and use short names to access specific functions without having to type the full package name every time.

```julia
import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
```

Any other additional package that you might need, e.g., for printing, plotting, exporting results etc. can be declared in the same way.

Also, the solution of the optimization problem will require an MILP solver.
As FlexPlan depends on [JuMP](https://github.com/jump-dev/JuMP.jl) package, it can be interfaced with any of the [optimisation solvers supported by JuMP](https://jump.dev/JuMP.jl/stable/installation/#Supported-solvers).
You can declare and initialize the solver as follows:

```julia
import HiGHS
optimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, "output_flag"=>false)
```

!!! tip
    FlexPlan exports `JuMP.optimizer_with_attributes` function, so you don't have to import JuMP just to use this function.


## 2. Input data

The data model of FlexPlan is very similar to the ones of PowerModels/PowerModelsACDC.
As such, a data dictionary containing all information is passed to the optimisation problem.
The standard network elements such as generators, buses, branches, etc. are extended with the existing and candidate storage and demand flexibility elements (see section [Data model](@ref) for complete description).
The multi-network modelling functionality of PowerModels is used to represent the different number of scenarios, planning years and planning hours within the year.
The procedure is further explained under section [Model dimensions](@ref).

### FlexPlan.jl sample data

The package contains some sample test cases comprising both grid data and multi-scenario time series, located under [`/test/data/`](https://github.com/Electa-Git/FlexPlan.jl/tree/master/test/data) and named as its subdirectories.
These test cases have been used in for the validation of the model in the FlexPlan deliverable 1.2 ["Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability"](https://flexplan-project.eu/wp-content/uploads/2022/08/D1.2_20220801_V2.0.pdf).

[`/test/io/load_case.jl`](https://github.com/Electa-Git/FlexPlan.jl/blob/master/test/io/load_case.jl) provides functions to load such test cases.
The functions are named `load_*` where `*` is the name of a test case.
For example, `case6` can be loaded using:
```julia
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
include(joinpath(_FP_dir,"test/io/load_case.jl"))
data = load_case6(; number_of_hours=24, number_of_scenarios=1, number_of_years=1)
```
Supported parameters are explained in `load_*` function documentation: in a Julia REPL, type `?` followed by a function name to read its documentation.

### Using your own data

FlexPlan provides functions that facilitate the construction of a multinetwork data dictionary using:
- network data from Matpower-like `.m` files;
- time series data from dictionaries of vectors, each vector being a time series.

The procedure is as follows.
1.  Create a single-network data dictionary.
    1.  Load network data from Matpower-like `.m` files (see e.g. [`/test/data/case6/case6_2030.m`](https://github.com/Electa-Git/FlexPlan.jl/blob/master/test/data/case6/case6_2030.m)). Use `parse_file`.
    2.  Specify the dimensions of the data. Use `add_dimension!`.
    3.  Scale costs and lifetime of grid expansion elements. Use `scale_data!`.
2.  Create a dictionary of vectors that contains time series. You have to write your own code for performing this step.
3.  Create a multinetwork data dictionary by combining the single-network data dictionary and the time series. Use `make_multinetwork`.

Here is some sample code to get started:
```julia
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
sn_data = _FP.parse_file(joinpath(_FP_dir,"test/data/case6/case6_2030.m"))
_FP.add_dimension!(sn_data, :hour, 24)
_FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)))
_FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
_FP.scale_data!(sn_data)

include(joinpath(_FP_dir,"test/io/create_profile.jl")) # Functions to load sample time series. Use your own instead.
sn_data, loadprofile, genprofile = create_profile_data_italy!(sn_data)
time_series = create_profile_data(24, sn_data, loadprofile, genprofile) # Your time series should have the same format as this `time_series` dict

mn_data = _FP.make_multinetwork(sn_data, time_series)
```

### Coupling of transmission and distribution networks

FlexPlan provides the possiblity to couple multiple radial distribution networks to the transmission system, for solving the combined T&D grid expansion problem.
For the meshed transmission system the linearized 'DC' power flow formulation is used, whereas radial networks are modelled using the linearized DistFlow model (more information can be found under [Network formulations](@ref) section).

Input data consist of:
- one dictionary for the trasmission network;
- a vector of dictionaries, each item representing one distribution network.

The only difference with respect to the case of a single network is that for each distribution network it is necessary to specify which bus of the transmission network it is to be attached to.
This is done by adding a `t_bus` key in the distribution network dictionary.

Here is an example (using FlexPlan sample data):
```julia
number_of_hours = 4
number_of_scenarios = 2
number_of_years = 1
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
include(joinpath(_FP_dir, "test/io/load_case.jl"))

# Transmission network data
t_data = load_case6(; number_of_hours, number_of_scenarios, number_of_years)

# Distribution network 1 data
d_data_sub_1 = load_ieee_33(; number_of_hours, number_of_scenarios, number_of_years)
d_data_sub_1["t_bus"] = 3 # States that this distribution network is attached to bus 3 of transmission network

# Distribution network 2 data
d_data_sub_2 = deepcopy(d_data_sub_1)
d_data_sub_2["t_bus"] = 6

d_data = [d_data_sub_1, d_data_sub_2]
```

## 3. Solve the problem

Finally, the problem can be solved using (example of stochastic planning problem with storage & demand flexiblity candidates):

```julia
result = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, optimizer; setting=Dict("conv_losses_mp"=>false))
```
of, for the combined T&D model:
```julia
result = _FP.simple_stoch_flex_tnep(t_data, d_data, _PM.DCPPowerModel, _FP.BFA8PowerModel, optimizer; t_setting=Dict("conv_losses_mp"=>false))
```

For other possible problem types and decomposed models, please check the [Problem types](@ref) section.

## 4. Inspect your results

The optimization results are returned as a Julia `Dict`, so you can easily write your custom code to retrieve the results you need.
However some basic functions for displaying and exporting results are provided in the package.

### Check termination status

First thing to do is check the [termination status](https://jump.dev/JuMP.jl/stable/moi/manual/solutions/) of the solver to make sure that an optimal solution has been found.

You may want to check the value of `"termination_status"` like this:
```julia
@assert result["termination_status"] ∈ (_FP.OPTIMAL, _FP.LOCALLY_SOLVED) "$(result["optimizer"]) termination status: $(result["termination_status"])"
```

!!! tip
    FlexPlan exports JuMP's `TerminationStatusCode` and `ResultStatusCode`, so you can access these types as above, without having to import JuMP just for that.

### Check solve time

The total solve time is also available, under `"solve_time"`:
```julia
println("Total solve time: $(round(result["solve_time"], digits=1)) seconds.")
```

### Access solution

To obtain power flow results, you can use the `print_summary` and `component_table` functions of PowerModels.

Further, several functions are provided to access to optimal investments and costs by category, view power profiles, and display the network topology.
Generally, they return a [DataFrame](https://dataframes.juliadata.org/stable/).
They also allow you to save numerical results as CSV files and plots in any format supported by [Plots.jl](https://docs.juliaplots.org/stable/).
All these functions are contained in [`/test/io/sol.jl`](https://github.com/Electa-Git/FlexPlan.jl/blob/master/test/io/sol.jl), but are not part of FlexPlan module to avoid unwanted dependencies.
Include them with
```julia
const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package
include(joinpath(_FP_dir,"test/io/sol.jl"))
```
and import the required packages.
