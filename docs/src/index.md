# FlexPlan.jl Documentation

```@meta
CurrentModule = FlexPlan
```

## Overview

FlexPlan.jl is a Julia/JuMP package to carry out transmission and distribution network planning considering, ac and dc technology, storage and demand flexibility as possible expansion candidates. Using time series input on renewble generation and demand, as well a list of candidates for grid expansion, a mixed-integer linear problem is cosntrcuted which can be solved with any commercial or open-source MILP solver. Some modelling features are:

- Multi-period, multi-stage formulation to model a number of planning years, and planning hours within years for a sequential grid expansion plan
- Stoachestic formulation of the planning problem, based on scenario probabilities for a number of different time series
- Linearized DistFlow model considering reactive power and voltage magnitudes for radial distribution grids
- Extensive, parametrized models for storage, demand flexibility and dc grids
- Different decomposition methods for solving the large-scale MILP problem

This package builds upon the PowerModels.jl and PowerModelsACDC.jl packages, and uses a similar structure.

Developed by:
- Hakan Ergun, KU Leuven / EnergyVille
- Matteo Rossi, RSE
- Marco Rossi, RSE 
- Damien Lapage, N-Side
- Iver Bakken Sperstad, SINTEF
- Espen Flo Bødal, SINTEF
- Merkebu Zenebe Degefa, SINTEF 
- Reinhilde D'hulst, VITO / EnergyVille

## Installation of FlexPlan

The latest stable release of FlexPlan can be installed using the Julia package manager with:

```julia
] add "FlexPlan"
```

## Acknowledgement
This software implementation is conducted within the European Union’s Horizon  2020 research and innovation programme under the FlexPlan project (grantagreement no. 863819).

## Special Thanks To
Carleton Coffrin (Los Alamos National Laboratory) for his countless design tips.  
