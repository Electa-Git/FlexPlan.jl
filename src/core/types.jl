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
# Using `@im_fields` instead of `@pm_fields` because the latter requires to be explicitly
# qualified (i.e. prepend `PowerModels.` instead of `_PM.`). The two macros are equal at the
# moment, but this may need to be changed if they will differ at some point.
mutable struct BFARadPowerModel <: _PM.AbstractBFAModel _PM.@im_fields end
