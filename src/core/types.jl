# Extends PowerModels/src/core/types.jl


##### Linear Approximations #####

"""
Linearized AC power flow model for radial networks.

Variables:
- squared voltage magnitude;
- active power;
- reactive power.

Hypotheses:
- same voltage angle for all buses;
- no line losses;
- line shunt admittances modeled as bus shunt loads.
"""
mutable struct LACRadPowerModel <: _PM.AbstractPowerModel _PM.@pm_fields end
