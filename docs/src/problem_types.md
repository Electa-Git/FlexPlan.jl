# Problem types

The FlexPlan.jl package contains the following problem types:

## T(D)NEP problem with storage candidates

This problem solves the AC/DC grid TNEP problem considering existing and candidate storage candidates. As such, starting from an AC / (DC) network with existing storage devices, the optmisation problem finds the best AC and DC grid investments as well as storage investments. The objective function is defined as follows:

Sets:
```math
\begin{aligned}
bc \in BC &- \text{Set of candidate AC lines} \\
dc \in DC &- \text{Set of candidate DC lines}  \\
cc \in CC &- \text{Set of candidate DC converters}  \\
sc \in SC &- \text{Set of candidate storage devices}  \\
g \in G &- \text{Set of candidate DC converters}  \\
t \in T &- \text{Set of planning hours}  \\
y \in Y &- \text{Set of planning years}  \\
\end{aligned}
```
Variables & parameters:

```math
\begin{aligned}
\alpha_{bc, y} &- \text{Binary investment decision variable of candidate AC line bc} \\
\alpha_{dc, y} &- \text{Binary investment decision variable of candidate DC line dc}\\
\alpha_{cc, y} &- \text{Binary investment decision variable of candidate DC converter cc}\\
\alpha_{sc, y} &- \text{Binary investment decision variable of candidate storage sc} \\
P_{g} &- \text{Active power output of generator g} \\
C_{bc, y} &- \text{Investment cost of candidate AC line bc}\\
C_{dc, y} &- \text{Investment cost of candidate DC line dc} \\
C_{cc, y} &- \text{Investment cost of candidate DC converter cc}\\
C_{sc, y} &- \text{Investment cost of candidate storage sc} \\
\end{aligned}
```

```math
min~\sum_{y \in Y} \left[ \sum_{bc \in BC} C_{bc}\alpha_{bc, y} + \sum_{dc \in BC} C_{dc}\alpha_{dc, y} + \sum_{cc \in CC} C_{cc}\alpha_{cc, y} + \sum_{sc \in BC} C_{sc}\alpha_{sc, y} + \sum_{t \in T}~ \sum_{g \in G} C_{g,t,y}P_{g,t,y} \right]
```

The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:

```julia
result_tnep = FlexPlan.strg_tnep(data, PowerModels.DCPPowerModel, solver; setting)
result_dnep = FlexPlan.strg_tnep(data, FlexPlan.BFA8PowerModel, solver; setting)
```
## TNEP problem with storage candidates and demand flexibility (Flexible T(D)NEP)

This problem solves the AC/DC grid TNEP problem considering existing and candidate storage candidates as well demand flexibility. As such, starting from an AC / (DC) network with existing storage devices, the optmisation problem finds the best AC and DC grid investments as well as storage and demand flexibility investments. The objective function is defined in addition to the TNEP problem with storage candidates as follows:

```math
min~\sum_{y \in Y} \left[ \sum_{bc \in BC} C_{bc}\alpha_{bc, y} + \sum_{dc \in BC} C_{dc}\alpha_{dc, y} + \sum_{cc \in CC} C_{cc}\alpha_{cc, y} + \sum_{sc \in BC} C_{sc}\alpha_{sc, y} + \sum_{t \in T}~ \sum_{g \in G} C_{g,t,y}P_{g,t,y} + \sum_{t \in T}~ \sum_{fc \in FC} \left( C_{fc,t,y}^{up}P_{fc,t,y}^{up} + C_{fc,t,y}^{down}P_{fc,t,y}^{down} + C_{fc,t,y}^{red}P_{fc,t,y}^{red} + C_{fc,t,y}^{curt}P_{fc,t,y}^{curt} \right)\right]
```

Sets:
```math
\begin{aligned}
fc \in FC &- \text{Set of demand flexibility investments} \\
\end{aligned}
```
Variables & parameters:

```math
\begin{aligned}
\alpha_{fc, y} &- \text{Binary investment decision variable for demand flexibility} \\
P_{fc}^{up} &- \text{Upwards demand shifting for flexible demand fc} \\
P_{fc}^{down} &- \text{Downwards demand shifting for flexible demand fc} \\
P_{fc}^{red} &- \text{Demand reduction for flexible demand fc} \\
P_{fc}^{curt} &- \text{Demand curtailment for flexible demand fc} \\
C_{fc}^{up} &- \text{Cost of upwards demand shifting for flexible demand fc} \\
C_{fc}^{down} &- \text{Cost of downwards demand shifting for flexible demand fc} \\
C_{fc}^{red} &- \text{Cost of voluntarydemand  reduction for flexible demand fc} \\
C_{fc}^{curt} &- \text{Cost of involuntary demand curtailment for flexible demand fc} \\
\end{aligned}
```

The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:

```julia
result_tnep = FlexPlan.flex_tnep(data, PowerModels.DCPPowerModel, solver; setting)
result_dnep = FlexPlan.flex_tnep(data, FlexPlan.BFA8PowerModel, solver; setting)
```

Additionally, this particular problem can also be solved for both transmission and distribution networks combined, using specific data for both the transmission and the distribution network:

```julia
result_t_and_d_nep = FlexPlan.flex_tnep(t_data, d_data, PowerModels.DCPPowerModel, FlexPlan.BFA8PowerModel, solver; setting)
```

## Stochastic flexbile T(D)NEP

This problem type extends the multi-year, multi-hour planning problem for a number of scenarios, e.g., variations of the planning year, and optimizes the investments taking into account the explicit scenario probabilities. As such, the objective is extended as follows, w.r.t. to the flexbile T(D)NEP problem:

Sets:
```math
\begin{aligned}
s \in S &- \text{Set of planning scearios} \\
\end{aligned}
```

Parameters:

```math
\begin{aligned}
\pi_{s} &- \text{Probability of scenario s} \\
\end{aligned}
```

```math
min~\sum_{s \in S} \pi_{s} \left\{ \sum_{y \in Y} \left[ \sum_{bc \in BC} C_{bc}\alpha_{bc, y} + \sum_{dc \in BC} C_{dc}\alpha_{dc,y} + \sum_{cc \in CC} C_{cc}\alpha_{cc,y} + \sum_{sc \in BC} C_{sc}\alpha_{sc,y} + \sum_{t \in T}~ \sum_{g \in G} C_{g,t,y,s}P_{g,t,y,s} + \sum_{t \in T}~ \sum_{fc \in FC} \left( C_{fc,t,y,s}^{up}P_{fc,t,y,s}^{up} + C_{fc,t,y,s}^{down}P_{fc,t,y,s}^{down} + C_{fc,t,y,s}^{red}P_{fc,t,y,s}^{red} + C_{fc,t,y,s}^{curt}P_{fc,t,y,s}^{curt} \right)\right] \right\}
```
The problem is defined both for transmission networks, using the linearised 'DC' power flow model as well as radial distribution grids using the linearised 'DistFlow' formulation. The problem can be solved using the following function:

```julia
result_tnep = FlexPlan.stoch_flex_tnep(data, PowerModels.DCPPowerModel, solver; setting)
result_dnep = FlexPlan.stoch_flex_tnep(data, FlexPlan.BFA8PowerModel, solver; setting)
```
