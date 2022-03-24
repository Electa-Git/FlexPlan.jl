## How to run scripts

A number of example scripts have been provided within ```FlexPlan.jl``` under ```"FlexPlan/examples"```. The general structure of the example scripts is as follows.

## Step 1: Declaration of the required packages and solvers

The required packages for FlexPlan.jl are ```PowerModels.jl``` and ```PowerModelsACDC.jl```. You can declare the packages as follows, and use short names to access specific functions without having to type the full package name every time.

``` julia
import PowerModels; const _PM = PowerModels
import PowerModelsACDC; const _PMACDC = PowerModelsACDC
import FlexPlan; const _FP = FlexPlan
```
Any other additional package that you might need, e.g., for printing, plotting, exporting results etc. can be declared in the same way.

Also, the solution of the problem will require an MILP solver. As ```FlexPlan.jl``` is in the Julia / JuMP environment, it can be interfaced with any optimisation solver. You can declare and initialize the solver as follows:

``` julia
import Cbc
optimizer = _FP.optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0)
```

## Step 2: Input data
The data model is very similar to the ```PowerModels.jl```/```PowerModelsACDC.jl``` data models. As such, a data dictionary containing all information is passed to the optimisation problem. The standard network elements such as generators, buses, branches, etc. are extended with the existing and candidate storage and demand flexibility elements. The multi-network modelling functionality of the PowerModels.jl package is used to represent the different number of scenarios, planning years and planning hours within the year. The procedure is further explained under section [Model dimensions](@ref). The package contains some sample time-series as well as grid data, which is located under `FlexPlan/test/data`. This data has been used in for the validation of the model in the FlexPlan deliverable 1.2 ["Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability"](https://flexplan-project.eu/wp-content/uploads/2021/03/D1.2_20210325_V1.0.pdf)

The data dictionary can be created by the user directly (see section [Data model](@ref) for complete description) but also provided as a MatPower file, as within PowerModels.jl. Using the MatPower file, only the grid data dictionary will be created. In order to add time-series and scenario information to the data dictionary, a number of additional functions are required. An example of the process is illustrated below for the combined T&D planning model:

```julia
# Define number of hours
number_of_hours = 24
# Transmission network instance (all data preparation except for make_multinetwork() call)
t_file = "./test/data/case6/case6_2030.m" # Input case for transmission network

t_data = _FP.parse_file(t_file) # Parse input file to obtain data dictionary
_FP.add_dimension!(t_data, :hour, number_of_hours) # Add dimension, e.g. hours
_FP.add_dimension!(t_data, :scenario, Dict(1 => Dict{String,Any}("probability"=>1)), metadata = Dict{String,Any}("mc"=>true)) # Add dimension, e.g. scenarios
_FP.add_dimension!(t_data, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1)) # Add_dimension, e.g. years
_FP.add_dimension!(t_data, :sub_nw, 1) # Add dimension, e.g. underlying networks
_FP.scale_data!(t_data) # Scale investment & operational cost data based on planning years & hours
t_data, t_loadprofile, t_genprofile = create_profile_data_italy!(t_data) # Load time series data based demand and RES profiles of the six market zones in Italy from the data folder
t_time_series = create_profile_data(number_of_hours, t_data, t_loadprofile, t_genprofile) # Create time series data to be passed to the data dictionay
```

### Coupling of transmission and distribution networks

FlexPlan.jl provides the possiblity to couple multiple radial distribution networks to the transmission system, for solving the combined T&D grid expansion problem. For the meshed transmission system the linearized 'DC' power flow formulation is used, whereas radial networks are modelled using the linearised DistFlow model (more information can be found under section [Network formulations](@ref)).

To create the data for radial networks you can use following approach:

```julia
## Distribution network instance 1 (all data preparation except for make_multinetwork() call)

d_file     = "test/data/cigre_mv_eu/cigre_mv_eu.m" # Input case for distribution networks
scale_load = 1.0 # Scaling factor of loads
scale_gen  = 1.0 # Scaling factor of generators

d_data_1 = _FP.parse_file(d_file) # Parse input file to obtain data dictionary
_FP.add_dimension!(d_data_1, :hour, number_of_hours) # Add dimension, e.g. hours
_FP.add_dimension!(d_data_1, :scenario, Dict(1 => Dict{String,Any}("probability"=>1))) # Add dimension, e.g. scenarios
_FP.add_dimension!(d_data_1, :year, 1; metadata = Dict{String,Any}("scale_factor"=>1)) # Add dimension, e.g. years
_FP.add_dimension!(d_data_1, :sub_nw, 1) # Add dimension, e.g. underlying networks
_FP.shift_ids!(d_data_1, _FP.dim_length(t_data)) # Shift network IDs to avoid overwriting those of transmission network
_FP.scale_data!(d_data_1) # Scale investment & operational cost data based on planning years & hours
d_time_series = create_profile_data_cigre(d_data_1, number_of_hours; scale_load, scale_gen) # Load time series data based demand and RES profiles of the six market zones in Italy from the data folder
_FP.add_td_coupling_data!(t_data, d_data_1; t_bus = 1, sub_nw = 1) # Connect the first distribution network to bus 1 of transmission network.
```
Note that a number of different distribution networks can be created in the same way. Eventually, all networks are coupled (for an example with one transmission and two distribution networks) using:

```julia
## Multinetwork data preparation

t_mn_data = _FP.make_multinetwork(t_data, t_time_series) # Merge transmission data & time series data
d_data_1 = _FP.make_multinetwork(d_data_1, d_time_series) # Merge data & time series data for distribution network 1
d_data_2 = _FP.make_multinetwork(d_data_2, d_time_series) # Merge data & time series data for distribution network 2
d_mn_data = _FP.merge_multinetworks!(d_data_1, d_data_2, :sub_nw) # Merge the two distribution networks in a single data dictionary
```

## Solving the problem

Finally, the problem can be solved using (example of planning problem with storage & demand flexiblity candidates):

```julia
result = _FP.flex_tnep(t_mn_data, d_mn_data, _PM.DCPPowerModel, _FP.BFARadPowerModel, optimizer; setting=s)
```

For other possible problem types and decomposed models, please check the section [Problem types](@ref).

## Inspecting your results

To obtain power flow results, you can use the standard `print_summary` function of ```PowerModels.jl```.
Further, there are number of possibilities to plot your time series results and also a ```.kml``` export, if you provide the latitude and longitude of the buses as an additional entry in your ```data["bus"]``` dictionary. Please consult ```FlexPlan/examples``` for different plotting possibilities.