# FlexPlan.jl

Status:
[![CI](https://github.com/Electa-Git/FlexPlan.jl/workflows/CI/badge.svg)](https://github.com/Electa-Git/FlexPlan.jl/actions?query=workflow%3ACI)
<a href="https://codecov.io/gh/Electa-Git/FlexPlan.jl"><img src="https://img.shields.io/codecov/c/github/Electa-Git/FlexPlan.jl?logo=Codecov"></img></a>
<a href="https://electa-git.github.io/FlexPlan.jl/dev/"><img src="https://github.com/Electa-Git/FlexPlan.jl/workflows/Documentation/badge.svg"></img></a>


## Overview

FlexPlan.jl is a Julia/JuMP package to carry out transmission and distribution network planning considering AC and DC technology, storage and demand flexibility as possible expansion candidates.
Using time series input on renewable generation and demand, as well a list of candidates for grid expansion, a mixed-integer linear problem is constructed which can be solved with any commercial or open-source MILP solver.
The package builds upon the [PowerModels](https://github.com/lanl-ansi/PowerModels.jl) and [PowerModelsACDC](https://github.com/Electa-Git/PowerModelsACDC.jl) packages, and uses a similar structure.

Some modelling features are:

- Joint multistage, multiperiod formulation to model a number of planning years, and planning hours within years for a sequential grid expansion plan.
- Stochastic formulation of the planning problem, based on scenario probabilities for a number of different time series.
- Extensive, parametrized models for storage, demand flexibility and DC grids.
- Linearized DistFlow model for radial distribution networks, considering reactive power and voltage magnitudes.
- Support of networks composed of transmission and distribution (T&D), with the possibility of using two different power flow models.
- Heuristic procedure for efficient, near-optimal planning of T&D networks.
- Basic implementations of Benders decomposition algorithm to efficiently solve the stochastic planning problem.


## Documentation

The package [documentation](https://electa-git.github.io/FlexPlan.jl/dev/) includes useful information comprising links to [example scripts](https://electa-git.github.io/FlexPlan.jl/dev/examples/) and a [tutorial](https://electa-git.github.io/FlexPlan.jl/dev/tutorial/).

Additionally, these presentations provide a brief introduction to various aspects of FlexPlan:

- Network expansion planning with FlexPlan.jl [[PDF](/docs/src/assets/20230216_flexplan_seminar_energyville.pdf)] – EnergyVille, 16/02/2023

All notable changes to the source code are documented in the [changelog](/CHANGELOG.md).

## Installation of FlexPlan

From Julia, FlexPlan can be installed using the built-in package manager:
```julia
using Pkg
Pkg.add("FlexPlan")
```

## Development

FlexPlan.jl is research-grade software and is constantly being improved and extended.
If you have suggestions for improvement, please contact us via the Issues page on the repository.

## Acknowledgements

This code has been developed as part of the European Union’s Horizon 2020 research and innovation programme under the FlexPlan project (grant agreement no. 863819).

Developed by:

- Hakan Ergun (KU Leuven / EnergyVille)
- Matteo Rossini (RSE)
- Marco Rossi (RSE)
- Damien Lepage (N-Side)
- Iver Bakken Sperstad (SINTEF)
- Espen Flo Bødal (SINTEF)
- Merkebu Zenebe Degefa (SINTEF)
- Reinhilde D'Hulst (VITO / EnergyVille)

The developers thank Carleton Coffrin (Los Alamos National Laboratory) for his countless design tips.

## License

This code is provided under a [BSD 3-Clause License](/LICENSE).
