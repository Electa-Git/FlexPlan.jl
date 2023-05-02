# FlexPlan.jl Documentation

```@meta
CurrentModule = FlexPlan
```

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

These presentations provide a brief introduction to various aspects of FlexPlan:

- Network expansion planning with FlexPlan.jl [[PDF](./assets/20230216_flexplan_seminar_energyville.pdf)] – EnergyVille, 16/02/2023

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

This code is provided under a [BSD 3-Clause License](https://github.com/Electa-Git/FlexPlan.jl/blob/master/LICENSE.md).
