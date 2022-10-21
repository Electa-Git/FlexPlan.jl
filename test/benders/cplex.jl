# Functions to interact with CPLEX.Optimizer

import CPLEX
import JuMP

# To be used instead of `CPLEX.Optimizer()` to set up a log file for the CPLEX optimizer
function CPLEX_optimizer_with_logger(log_file::String)
    function CPLEX_opt_w_log() # Like CPLEX.Optimizer, but dumps to the specified log file
        model = CPLEX.Optimizer()
        CPLEX.CPXsetlogfilename(model.env, log_file, "w+")
        return model
    end
end

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
