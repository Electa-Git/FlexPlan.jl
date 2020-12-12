"""
    read_case_data_from_csv(data,filename,field_input)

Reads auxiliary case data from .csv file 'filename' and adds it to the 
field 'field_input' of the FlexPlan case input data Dict 'data' 
(e.g. read from a MATPOWER case with auxiliary fields of the mpc data structure.)    
"""
function read_case_data_from_csv(data,filename,field_input)
    
    case_input = CSV.read(filename)
    size_input = size(case_input)
    n_cols = size_input[2]
    n_data_rows = size_input[1]
    param_names = names(case_input)

    if field_input == "load_extra"        
        #field_name = "load"
        field_name = "load_extra"
        #dict_in_data = data[field_name]
        dict_in_data = Dict()
        for i_row = 1:n_data_rows            
            push!(dict_in_data,string(i_row) => Dict())
        end
    else
        dict_in_data = Dict()
        error("Only field_input = 'load_extra' is currently supported")
    end

    for i_col = 1:n_cols
        param_name = param_names[i_col]
        for i_row = 1:n_data_rows            
            push!(dict_in_data[string(i_row)], param_name => case_input[i_row,i_col])
        end
    end

    if field_input == "load_extra"
        #data[field_name] = dict_in_data
        push!(data,field_name => dict_in_data)
    else
        #push!(data,field_name => dict_in_data)
    end

    return data
end

