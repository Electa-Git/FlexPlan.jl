# Extends PowerModels/src/core/types.jl


##### Linear Approximations #####

"""
Linearized AC branch flow model for radial networks.

Variables:
- squared voltage magnitude;
- branch active power;
- branch reactive power.

Properties:
- same voltage angle for all buses;
- lossless.

Differences with respect to `BFAPowerModel`:
- shunt admittances of the branches are neglected;
- the complex power in the thermal limit constraints of the branches is limited by an octagon
  instead of a circle, so as to keep the model linear. 
"""
mutable struct BFARadPowerModel <: _PM.AbstractBFAModel _PM.@pm_fields end
