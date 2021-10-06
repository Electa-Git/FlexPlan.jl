# Functions to interact with CPLEX.Optimizer

import JuMP

function get_cplex_optimizer(pm::_PM.AbstractPowerModel)
    m1 = pm.model # JuMP.model
    m2 = JuMP.backend(m1) # MathOptInterface.Utilities.CachingOptimizer{...}
    m3 = m2.optimizer # MathOptInterface.Bridges.LazyBridgeOptimizer{CPLEX.Optimizer}
    m4 = m3.model # CPLEX.Optimizer
    return m4
end

function get_num_subproblems(annotation_file::String)
    subproblems = 0
    for line in eachline(annotation_file)
        m = match(r"<anno .*value='(?<value>\d+)'.*/>", line)
        if !isnothing(m)
            val = parse(Int, m[:value])
            if val > subproblems
                subproblems = val
            end
        end
    end
    return subproblems
end
