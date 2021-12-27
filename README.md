# FlexPlan.jl

Status:
[![CI](https://github.com/Electa-Git/FlexPlan.jl/workflows/CI/badge.svg)](https://github.com/Electa-Git/FlexPlan.jl/actions?query=workflow%3ACI)
<a href="https://codecov.io/gh/Electa-Git/FlexPlan.jl"><img src="https://img.shields.io/codecov/c/github/Electa-Git/FlexPlan.jl?logo=Codecov"></img></a>
<a href="https://electa-git.github.io/FlexPlan.jl/dev/"><img src="https://github.com/Electa-Git/FlexPlan.jl/workflows/Documentation/badge.svg"></img></a>


## Overview

FlexPlan.jl is a Julia/JuMP package to carry out transmission and distribution network planning considering AC and DC technology, storage and demand flexibility as possible expansion candidates. Using time series input on renewble generation and demand, as well a list of candidates for grid expansion, a mixed-integer linear problem is constructed which can be solved with any commercial or open-source MILP solver. Some modelling features are:

- Multi-period, multi-stage formulation to model a number of planning years, and planning hours within years for a sequential grid expansion plan
- Stochastic formulation of the planning problem, based on scenario probabilities for a number of different time series
- Linearized DistFlow model considering reactive power and voltage magnitudes for radial distribution grids
- Extensive, parametrized models for storage, demand flexibility and DC grids
- Different decomposition methods for solving the large-scale MILP problem

This package builds upon the PowerModels.jl and PowerModelsACDC.jl packages, and uses a similar structure.

## Collaboration / improvements
Please note that FlexPlan.jl is research-grade software library and is constantly being improved and extended. If you have suggetions for improvement, please contact us via the issues page on the repository.

## Developed by:
- Hakan Ergun, KU Leuven / EnergyVille
- Matteo Rossini, RSE
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
This software implementation is conducted within the European Union’s Horizon  2020 research and innovation programme under the FlexPlan project (grant agreement no. 863819).

## Special Thanks To
Carleton Coffrin (Los Alamos National Laboratory) for his countless design tips.
