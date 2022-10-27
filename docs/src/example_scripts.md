## How to run scripts

A number of example scripts have been provided within `FlexPlan.jl` under `"FlexPlan/examples"`. The general structure of the example scripts is as follows.

## Step 1: Declaration of the required packages and solvers

The required packages for FlexPlan.jl are `PowerModels.jl` and `PowerModelsACDC.jl`. You can declare the packages as follows, and use short names to access specific functions without having to type the full package name every time.

``` julia
import PowerModels as _PM
import PowerModelsACDC as _PMACDC
import FlexPlan as _FP
```
Any other additional package that you might need, e.g., for printing, plotting, exporting results etc. can be declared in the same way.

Also, the solution of the problem will require an MILP solver. As ```FlexPlan.jl``` is in the Julia / JuMP environment, it can be interfaced with any optimisation solver. You can declare and initialize the solver as follows:

``` julia
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
```

## Step 2: Input data

The data model is very similar to the `PowerModels.jl`/`PowerModelsACDC.jl` data models. As such, a data dictionary containing all information is passed to the optimisation problem. The standard network elements such as generators, buses, branches, etc. are extended with the existing and candidate storage and demand flexibility elements (see section [Data model](@ref) for complete description). The multi-network modelling functionality of the PowerModels.jl package is used to represent the different number of scenarios, planning years and planning hours within the year. The procedure is further explained under section [Model dimensions](@ref).

### FlexPlan.jl sample data

The package contains some sample test cases comprising both grid data and time series, located under `FlexPlan/test/data` and named as its subdirectories.
These test cases have been used in for the validation of the model in the FlexPlan deliverable 1.2 ["Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability"](https://flexplan-project.eu/wp-content/uploads/2021/03/D1.2_20210325_V1.0.pdf).

`FlexPlan/test/io/load_case.jl` provides functions to load such test cases.
The functions are named `load_*` where `*` is the name of a test case.
For example, `case6` can be loaded using:
```julia
include("test/io/load_case.jl")
data = load_case6(; number_of_hours=24, number_of_scenarios=1, number_of_years=1)
```
Supported parameters are explained in `load_*` function documentation.

### Using your own data

FlexPlan.jl provides functions that facilitate the construction of a multinetwork data dictionary using:
- network data from MatPower-like `.m` files;
- time series data from dictionaries of vectors, each vector being a time series.

The procedure is as follows.
1.  Create a single-network data dictionary.
    1.  Load network data from MatPower-like `.m` files (see e.g. `FlexPlan/test/data/case6/case6_2030.m`) using `parse_file`.
    2.  Specify the dimensions of the data using `add_dimension!`.
    3.  Scale costs and lifetime of grid expansion elements using `scale_data!`.
2.  Create a dictionary of vectors that contains time series.
3.  Create a multinetwork data dictionary by combining the single-network data dictionary and the time series:

Here is some sample code to get started:
```julia
sn_data = _FP.parse_file("./test/data/case6/case6_2030.m")
_FP.add_dimension!(sn_data, :hour, 24)
_FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)))
_FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1))
_FP.scale_data!(sn_data)

include("./test/io/create_profile.jl") # Functions to load sample time series. Use your own instead.
sn_data, loadprofile, genprofile = create_profile_data_italy!(sn_data)
time_series = create_profile_data(24, sn_data, loadprofile, genprofile) # Your time series should have the same format as this `time_series` dict

mn_data = _FP.make_multinetwork(sn_data, time_series)
```

### Coupling of transmission and distribution networks

FlexPlan.jl provides the possiblity to couple multiple radial distribution networks to the transmission system, for solving the combined T&D grid expansion problem.
For the meshed transmission system the linearized 'DC' power flow formulation is used, whereas radial networks are modelled using the linearised DistFlow model (more information can be found under section [Network formulations](@ref)).

Input data consist of:
- one dictionary for the trasmission network;
- a vector of dictionaries, each item representing one distribution network.

The only difference with respect to the case of a single network is that for each distribution network it is necessary to specify which bus of the transmission network it is to be attached to.
This is done by adding a `t_bus` key in the distribution network dictionary.

Here is an example (using FlexPlan.jl sample data):
```julia
number_of_hours = 4
number_of_scenarios = 2
number_of_years = 1
include("./test/io/load_case.jl")

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

## Solving the problem

Finally, the problem can be solved using (example of stochastic planning problem with storage & demand flexiblity candidates):

```julia
result = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, optimizer; setting=Dict("conv_losses_mp"=>false))
```
of, for the combined T&D model:
```julia
result = _FP.simple_stoch_flex_tnep(t_data, d_data, _PM.DCPPowerModel, _FP.BFARadPowerModel, optimizer; t_setting=Dict("conv_losses_mp"=>false))
```

For other possible problem types and decomposed models, please check the section [Problem types](@ref).

## Inspecting your results

To obtain power flow results, you can use the standard `print_summary` function of `PowerModels.jl`.
Further, there are number of possibilities to plot your time series results and also a `.kml` export, if you provide the latitude and longitude of the buses as an additional entry in your `data["bus"]` dictionary.
Please consult `FlexPlan/examples` for different plotting possibilities.
