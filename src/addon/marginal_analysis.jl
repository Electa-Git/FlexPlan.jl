# Function for running model with specified data
function run_model(data, extradata, _PM, solver)
    mn_data = _FP.make_multinetwork(data, extradata)

    # Add PowerModels(ACDC) settings
    s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => false, "process_data_internally" => false)

    # Build optimisation model, solve it and write solution dictionary:
    # This is the "problem file" which needs to be constructed individually depending on application
    # In this case: multi-period optimisation of demand flexibility, AC & DC lines and storage investments
    res = _FP.flex_tnep(mn_data, _PM.DCPPowerModel, solver; setting = s)
    return res
end

# Function for marginal analysis
function marginal_analysis(marginal_param, data, extradata, _PM, solver)

    marginal_res = Dict()

    for (k, values) in marginal_param
        utype = k[1]
        unit = k[2]
        param = k[3]
        # Define set of units for changing marginal param
        if unit == "All"
            units = keys(data[utype])
        else
            units = [unit]
        end
        # Get original value
        original_value = Dict()
        for i in units
            original_value[i] = data[utype][i][param]
        end
        # Run model for all values in marginal anaysis
        for value in values
            for i in units
                data[utype][i][param] = value
            end
            marginal_res[value] = run_model(data, extradata, _PM, solver)
        end
        # Reset to original value
        for i in units
            data[utype][i][param] = original_value[i]
        end
    end
    return marginal_res
end
