var documenterSearchIndex = {"docs":
[{"location":"modeling_assumptions/#Modeling-assumptions","page":"Modelling assumptions","title":"Modeling assumptions","text":"","category":"section"},{"location":"modeling_assumptions/#Multiple-year-models","page":"Modelling assumptions","title":"Multiple-year models","text":"","category":"section"},{"location":"modeling_assumptions/","page":"Modelling assumptions","title":"Modelling assumptions","text":"When preparing data for problems spanning a multi-year horizon (here the word year indicates an investment period: different investment decisions can be made in different years), investment candidates must adhere to the following two assumptions:","category":"page"},{"location":"modeling_assumptions/","page":"Modelling assumptions","title":"Modelling assumptions","text":"If a candidate exists in a year, then it exists in all subsequent years and is defined in the same row of the corresponding table in the input data files.\nEach candidate has the same parameters in all the years in which it exists, except for the cost which may vary with the years.","category":"page"},{"location":"modeling_assumptions/","page":"Modelling assumptions","title":"Modelling assumptions","text":"These assumptions are used not only when parsing input data files, but also in some variables/constraints where an investment candidate must be tracked along years.","category":"page"},{"location":"problem_types/#Problem-types","page":"Problem types","title":"Problem types","text":"","category":"section"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"The FlexPlan.jl package contains the following problem types:","category":"page"},{"location":"problem_types/#T(D)NEP-problem-with-storage-candidates","page":"Problem types","title":"T(D)NEP problem with storage candidates","text":"","category":"section"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"This problem solves the AC/DC grid TNEP problem considering existing and candidate storage candidates. As such, starting from an AC / (DC) network with existing storage devices, the optmisation problem finds the best AC and DC grid investments as well as storage investments. The objective function is defined as follows:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Sets:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\nbc in BC - textSet of candidate AC lines \ndc in DC - textSet of candidate DC lines  \ncc in CC - textSet of candidate DC converters  \nsc in SC - textSet of candidate storage devices  \ng in G - textSet of candidate DC converters  \nt in T - textSet of planning hours  \ny in Y - textSet of planning years  \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Variables & parameters:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\nalpha_bc y - textBinary investment decision variable of candidate AC line bc \nalpha_dc y - textBinary investment decision variable of candidate DC line dc\nalpha_cc y - textBinary investment decision variable of candidate DC converter cc\nalpha_sc y - textBinary investment decision variable of candidate storage sc \nP_g - textActive power output of generator g \nC_bc y - textInvestment cost of candidate AC line bc\nC_dc y - textInvestment cost of candidate DC line dc \nC_cc y - textInvestment cost of candidate DC converter cc\nC_sc y - textInvestment cost of candidate storage sc \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"minsum_y in Y left sum_bc in BC C_bcalpha_bc y + sum_dc in BC C_dcalpha_dc y + sum_cc in CC C_ccalpha_cc y + sum_sc in BC C_scalpha_sc y + sum_t in T sum_g in G C_gtyP_gty right","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"result_tnep = FlexPlan.strg_tnep(data, PowerModels.DCPPowerModel, solver; setting)\nresult_dnep = FlexPlan.strg_tnep(data, FlexPlan.BFARadPowerModel, solver; setting)","category":"page"},{"location":"problem_types/#TNEP-problem-with-storage-candidates-and-demand-flexibility-(Flexible-T(D)NEP)","page":"Problem types","title":"TNEP problem with storage candidates and demand flexibility (Flexible T(D)NEP)","text":"","category":"section"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"This problem solves the AC/DC grid TNEP problem considering existing and candidate storage candidates as well demand flexibility. As such, starting from an AC / (DC) network with existing storage devices, the optmisation problem finds the best AC and DC grid investments as well as storage and demand flexibility investments. The objective function is defined in addition to the TNEP problem with storage candidates as follows:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"minsum_y in Y left sum_bc in BC C_bcalpha_bc y + sum_dc in BC C_dcalpha_dc y + sum_cc in CC C_ccalpha_cc y + sum_sc in BC C_scalpha_sc y + sum_t in T sum_g in G C_gtyP_gty + sum_t in T sum_fc in FC left( C_fcty^upP_fcty^up + C_fcty^downP_fcty^down + C_fcty^redP_fcty^red + C_fcty^curtP_fcty^curt right)right","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Sets:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\nfc in FC - textSet of demand flexibility investments \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Variables & parameters:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\nalpha_fc y - textBinary investment decision variable for demand flexibility \nP_fc^up - textUpwards demand shifting for flexible demand fc \nP_fc^down - textDownwards demand shifting for flexible demand fc \nP_fc^red - textDemand reduction for flexible demand fc \nP_fc^curt - textDemand curtailment for flexible demand fc \nC_fc^up - textCost of upwards demand shifting for flexible demand fc \nC_fc^down - textCost of downwards demand shifting for flexible demand fc \nC_fc^red - textCost of voluntarydemand  reduction for flexible demand fc \nC_fc^curt - textCost of involuntary demand curtailment for flexible demand fc \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"result_tnep = FlexPlan.flex_tnep(data, PowerModels.DCPPowerModel, solver; setting)\nresult_dnep = FlexPlan.flex_tnep(data, FlexPlan.BFARadPowerModel, solver; setting)","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Additionally, this particular problem can also be solved for both transmission and distribution networks combined, using specific data for both the transmission and the distribution network:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"result_t_and_d_nep = FlexPlan.flex_tnep(t_data, d_data, PowerModels.DCPPowerModel, FlexPlan.BFARadPowerModel, solver; setting)","category":"page"},{"location":"problem_types/#Stochastic-flexbile-T(D)NEP","page":"Problem types","title":"Stochastic flexbile T(D)NEP","text":"","category":"section"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"This problem type extends the multi-year, multi-hour planning problem for a number of scenarios, e.g., variations of the planning year, and optimizes the investments taking into account the explicit scenario probabilities. As such, the objective is extended as follows, w.r.t. to the flexbile T(D)NEP problem:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Sets:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\ns in S - textSet of planning scearios \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"Parameters:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"beginaligned\npi_s - textProbability of scenario s \nendaligned","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"minsum_s in S pi_s left sum_y in Y left sum_bc in BC C_bcalpha_bc y + sum_dc in BC C_dcalpha_dcy + sum_cc in CC C_ccalpha_ccy + sum_sc in BC C_scalpha_scy + sum_t in T sum_g in G C_gtysP_gtys + sum_t in T sum_fc in FC left( C_fctys^upP_fctys^up + C_fctys^downP_fctys^down + C_fctys^redP_fctys^red + C_fctys^curtP_fctys^curt right)right right","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:","category":"page"},{"location":"problem_types/","page":"Problem types","title":"Problem types","text":"result_tnep = FlexPlan.stoch_flex_tnep(data, PowerModels.DCPPowerModel, solver; setting)\nresult_dnep = FlexPlan.stoch_flex_tnep(data, FlexPlan.BFARadPowerModel, solver; setting)","category":"page"},{"location":"quickguide/#Quickguide","page":"Getting started","title":"Quickguide","text":"","category":"section"},{"location":"quickguide/#How-to-run-scripts","page":"Getting started","title":"How to run scripts","text":"","category":"section"},{"location":"quickguide/","page":"Getting started","title":"Getting started","text":"Some scripts have been provided in FlexPlan/test/scripts to test the package functionality. To run those scripts, you need to activate an environment and import all the needed packages.","category":"page"},{"location":"quickguide/","page":"Getting started","title":"Getting started","text":"In a Julia REPL, choose a directory where to create the environment:\njulia> cd(\"path/to/env/dir\")\nEnter the Pkg REPL by pressing ] from the Julia REPL:\njulia> ]\nActivate the environment:\npkg> activate .\nadd the FlexPlan package:\npkg> add FlexPlan\nadd every package required by the script. For example, if the script contains import Plots, then execute\npkg> add Plots","category":"page"},{"location":"network_formulations/#Network-formulations","page":"Network formulations","title":"Network formulations","text":"","category":"section"},{"location":"network_formulations/","page":"Network formulations","title":"Network formulations","text":"Two different network formulations have been used in the FlexPlan package:","category":"page"},{"location":"network_formulations/","page":"Network formulations","title":"Network formulations","text":"PowerModels.DCPPowerModel is a linearised 'DC' power flow formulation that represents meshed AC/DC transmission networks;\nFlexPlan.BFARadPowerModel is a linearised 'DistFlow' formulation that represents radial AC distribution networks.","category":"page"},{"location":"network_formulations/","page":"Network formulations","title":"Network formulations","text":"For the comprehensive formulation of the network equations, along with the detailed model for storage and demand flexibility, the readers are referred to the FlexPlan deliverable 1.2 \"Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability\"","category":"page"},{"location":"network_formulations/","page":"Network formulations","title":"Network formulations","text":"@article{ergun2021probabilistic,\n  title={Probabilistic optimization of T\\&D systems planning with high grid flexibility and its scalability},\n  author={Ergun, Hakan and Sperstad, Iver Bakken and Espen Flo, B{\\o}dal and Siface, Dario and Pirovano, Guido and Rossi, Marco and Rossini, Matteo and Marmiroli, Benedetta and Agresti, Valentina and Costa, Matteo Paolo and others},\n  year={2021}\n}","category":"page"},{"location":"dimensions/#Model-dimensions","page":"Model dimensions","title":"Model dimensions","text":"","category":"section"},{"location":"dimensions/","page":"Model dimensions","title":"Model dimensions","text":"All the optimization problems modeled in FlexPlan are multiperiod and make use of the following dimensions:","category":"page"},{"location":"dimensions/","page":"Model dimensions","title":"Model dimensions","text":"hour: the finest time granularity that can be represented in a model. During an hour, each continuous variable has a constant value.\nyear: an investment period. Different investment decisions can be made in different years.\nscenario: one of the different possible sets of values related to renewable generation and consumption data.","category":"page"},{"location":"dimensions/","page":"Model dimensions","title":"Model dimensions","text":"These dimensions must be defined in each model by calling the function add_dimension! on single-period data dictionaries. The add_dimension! function takes the name of the dimension as input in form of key, as well as either integer values, e.g., for number of hours or years, or a dictionary, e.g., containing multiple scenarios. In the case of scenario input, probabilities and other meta data can be added. An example can be found below:","category":"page"},{"location":"dimensions/","page":"Model dimensions","title":"Model dimensions","text":"_FP.add_dimension!(data, :hour, number_of_hours) # Add dimension, e.g. number of hours\n_FP.add_dimension!(data, :scenario, Dict(1 => Dict{String,Any}(\"probability\"=>1)), metadata = Dict{String,Any}(\"mc\"=>true)) # Add dimension, e.g. number of scenarios\n_FP.add_dimension!(t_data, :year, 1; metadata = Dict{String,Any}(\"scale_factor\"=>1)) # Add dimension of years, using cost scaling factors in metadata","category":"page"},{"location":"data_model/#Data-model","page":"Data model","title":"Data model","text":"","category":"section"},{"location":"data_model/","page":"Data model","title":"Data model","text":"FlexPlan.jl extends data models of the PowerModels.jl and PowerModelsACDC.jl packages by including candidate storage devices, :ne_storage, additional fields to parametrize the demand flexibility models which extend :load, some additional parameters to both existing and candidate storage devices to represent external charging and discharging of storage, e.g., to represent natural inflow and dissipation of water in hydro storage, some additional parameters extending :gen to include air quality impact and  CO2 emission costs for the generators.","category":"page"},{"location":"data_model/","page":"Data model","title":"Data model","text":"For the full data model please consult the FlexPlan deliverable 1.2 \"Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability\"","category":"page"},{"location":"data_model/","page":"Data model","title":"Data model","text":"@article{ergun2021probabilistic,\n  title={Probabilistic optimization of T\\&D systems planning with high grid flexibility and its scalability},\n  author={Ergun, Hakan and Sperstad, Iver Bakken and Espen Flo, B{\\o}dal and Siface, Dario and Pirovano, Guido and Rossi, Marco and Rossini, Matteo and Marmiroli, Benedetta and Agresti, Valentina and Costa, Matteo Paolo and others},\n  year={2021}\n}","category":"page"},{"location":"#FlexPlan.jl-Documentation","page":"Home","title":"FlexPlan.jl Documentation","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"CurrentModule = FlexPlan","category":"page"},{"location":"#Overview","page":"Home","title":"Overview","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"FlexPlan.jl is a Julia/JuMP package to carry out transmission and distribution network planning considering AC and DC technology, storage and demand flexibility as possible expansion candidates. Using time series input on renewble generation and demand, as well a list of candidates for grid expansion, a mixed-integer linear problem is constructed which can be solved with any commercial or open-source MILP solver. Some modelling features are:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Multi-period, multi-stage formulation to model a number of planning years, and planning hours within years for a sequential grid expansion plan\nStochastic formulation of the planning problem, based on scenario probabilities for a number of different time series\nLinearized DistFlow model considering reactive power and voltage magnitudes for radial distribution grids\nExtensive, parametrized models for storage, demand flexibility and DC grids\nDifferent decomposition methods for solving the large-scale MILP problem","category":"page"},{"location":"","page":"Home","title":"Home","text":"This package builds upon the PowerModels.jl and PowerModelsACDC.jl packages, and uses a similar structure.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Developed by:","category":"page"},{"location":"","page":"Home","title":"Home","text":"Hakan Ergun, KU Leuven / EnergyVille\nMatteo Rossini, RSE\nMarco Rossi, RSE\nDamien Lapage, N-Side\nIver Bakken Sperstad, SINTEF\nEspen Flo Bødal, SINTEF\nMerkebu Zenebe Degefa, SINTEF\nReinhilde D'hulst, VITO / EnergyVille","category":"page"},{"location":"#Installation-of-FlexPlan","page":"Home","title":"Installation of FlexPlan","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"The latest stable release of FlexPlan can be installed using the Julia package manager with:","category":"page"},{"location":"","page":"Home","title":"Home","text":"] add \"FlexPlan\"","category":"page"},{"location":"#Acknowledgement","page":"Home","title":"Acknowledgement","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"This software implementation is conducted within the European Union’s Horizon 2020 research and innovation programme under the FlexPlan project (grant agreement no. 863819).","category":"page"},{"location":"#Special-Thanks-To","page":"Home","title":"Special Thanks To","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Carleton Coffrin (Los Alamos National Laboratory) for his countless design tips.","category":"page"},{"location":"example_scripts/#How-to-run-scripts","page":"Example scripts","title":"How to run scripts","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"A number of example scripts have been provided within FlexPlan.jl under \"FlexPlan/examples\". The general structure of the example scripts is as follows.","category":"page"},{"location":"example_scripts/#Step-1:-Declaration-of-the-required-packages-and-solvers","page":"Example scripts","title":"Step 1: Declaration of the required packages and solvers","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"The required packages for FlexPlan.jl are PowerModels.jl and PowerModelsACDC.jl. You can declare the packages as follows, and use short names to access specific functions without having to type the full package name every time.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"import PowerModels as _PM\nimport PowerModelsACDC as _PMACDC\nimport FlexPlan as _FP","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Any other additional package that you might need, e.g., for printing, plotting, exporting results etc. can be declared in the same way.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Also, the solution of the problem will require an MILP solver. As FlexPlan.jl is in the Julia / JuMP environment, it can be interfaced with any optimisation solver. You can declare and initialize the solver as follows:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"import HiGHS\noptimizer = _FP.optimizer_with_attributes(HiGHS.Optimizer, \"output_flag\"=>false)","category":"page"},{"location":"example_scripts/#Step-2:-Input-data","page":"Example scripts","title":"Step 2: Input data","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"The data model is very similar to the PowerModels.jl/PowerModelsACDC.jl data models. As such, a data dictionary containing all information is passed to the optimisation problem. The standard network elements such as generators, buses, branches, etc. are extended with the existing and candidate storage and demand flexibility elements (see section Data model for complete description). The multi-network modelling functionality of the PowerModels.jl package is used to represent the different number of scenarios, planning years and planning hours within the year. The procedure is further explained under section Model dimensions.","category":"page"},{"location":"example_scripts/#FlexPlan.jl-sample-data","page":"Example scripts","title":"FlexPlan.jl sample data","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"The package contains some sample test cases comprising both grid data and time series, located under FlexPlan/test/data and named as its subdirectories. These test cases have been used in for the validation of the model in the FlexPlan deliverable 1.2 \"Probabilistic optimization of T&D systems planning with high grid flexibility and its scalability\".","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"FlexPlan/test/io/load_case.jl provides functions to load such test cases. The functions are named load_* where * is the name of a test case. For example, case6 can be loaded using:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package\ninclude(joinpath(_FP_dir,\"test/io/load_case.jl\"))\ndata = load_case6(; number_of_hours=24, number_of_scenarios=1, number_of_years=1)","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Supported parameters are explained in load_* function documentation.","category":"page"},{"location":"example_scripts/#Using-your-own-data","page":"Example scripts","title":"Using your own data","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"FlexPlan.jl provides functions that facilitate the construction of a multinetwork data dictionary using:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"network data from MatPower-like .m files;\ntime series data from dictionaries of vectors, each vector being a time series.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"The procedure is as follows.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Create a single-network data dictionary.\nLoad network data from MatPower-like .m files (see e.g. FlexPlan/test/data/case6/case6_2030.m) using parse_file.\nSpecify the dimensions of the data using add_dimension!.\nScale costs and lifetime of grid expansion elements using scale_data!.\nCreate a dictionary of vectors that contains time series.\nCreate a multinetwork data dictionary by combining the single-network data dictionary and the time series:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Here is some sample code to get started:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"const _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package\nsn_data = _FP.parse_file(joinpath(_FP_dir,\"test/data/case6/case6_2030.m\"))\n_FP.add_dimension!(sn_data, :hour, 24)\n_FP.add_dimension!(sn_data, :scenario, Dict(1 => Dict{String,Any}(\"probability\"=>1)))\n_FP.add_dimension!(sn_data, :year, 1; metadata = Dict{String,Any}(\"scale_factor\"=>1))\n_FP.scale_data!(sn_data)\n\ninclude(joinpath(_FP_dir,\"test/io/create_profile.jl\")) # Functions to load sample time series. Use your own instead.\nsn_data, loadprofile, genprofile = create_profile_data_italy!(sn_data)\ntime_series = create_profile_data(24, sn_data, loadprofile, genprofile) # Your time series should have the same format as this `time_series` dict\n\nmn_data = _FP.make_multinetwork(sn_data, time_series)","category":"page"},{"location":"example_scripts/#Coupling-of-transmission-and-distribution-networks","page":"Example scripts","title":"Coupling of transmission and distribution networks","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"FlexPlan.jl provides the possiblity to couple multiple radial distribution networks to the transmission system, for solving the combined T&D grid expansion problem. For the meshed transmission system the linearized 'DC' power flow formulation is used, whereas radial networks are modelled using the linearised DistFlow model (more information can be found under section Network formulations).","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Input data consist of:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"one dictionary for the trasmission network;\na vector of dictionaries, each item representing one distribution network.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"The only difference with respect to the case of a single network is that for each distribution network it is necessary to specify which bus of the transmission network it is to be attached to. This is done by adding a t_bus key in the distribution network dictionary.","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Here is an example (using FlexPlan.jl sample data):","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"number_of_hours = 4\nnumber_of_scenarios = 2\nnumber_of_years = 1\nconst _FP_dir = dirname(dirname(pathof(_FP))) # Root directory of FlexPlan package\ninclude(joinpath(_FP_dir, \"test/io/load_case.jl\"))\n\n# Transmission network data\nt_data = load_case6(; number_of_hours, number_of_scenarios, number_of_years)\n\n# Distribution network 1 data\nd_data_sub_1 = load_ieee_33(; number_of_hours, number_of_scenarios, number_of_years)\nd_data_sub_1[\"t_bus\"] = 3 # States that this distribution network is attached to bus 3 of transmission network\n\n# Distribution network 2 data\nd_data_sub_2 = deepcopy(d_data_sub_1)\nd_data_sub_2[\"t_bus\"] = 6\n\nd_data = [d_data_sub_1, d_data_sub_2]","category":"page"},{"location":"example_scripts/#Solving-the-problem","page":"Example scripts","title":"Solving the problem","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"Finally, the problem can be solved using (example of stochastic planning problem with storage & demand flexiblity candidates):","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"result = _FP.simple_stoch_flex_tnep(data, _PM.DCPPowerModel, optimizer; setting=Dict(\"conv_losses_mp\"=>false))","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"of, for the combined T&D model:","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"result = _FP.simple_stoch_flex_tnep(t_data, d_data, _PM.DCPPowerModel, _FP.BFARadPowerModel, optimizer; t_setting=Dict(\"conv_losses_mp\"=>false))","category":"page"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"For other possible problem types and decomposed models, please check the section Problem types.","category":"page"},{"location":"example_scripts/#Inspecting-your-results","page":"Example scripts","title":"Inspecting your results","text":"","category":"section"},{"location":"example_scripts/","page":"Example scripts","title":"Example scripts","text":"To obtain power flow results, you can use the standard print_summary function of PowerModels.jl. Further, there are number of possibilities to plot your time series results and also a .kml export, if you provide the latitude and longitude of the buses as an additional entry in your data[\"bus\"] dictionary. Please consult FlexPlan/examples for different plotting possibilities.","category":"page"}]
}
