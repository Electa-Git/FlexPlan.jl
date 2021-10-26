# Analyse characteristics of the Norwegian residential load demand time series

import CSV
import DataFrames

# Read data
demand_data = CSV.read("./test/data/demand_Norway_2015.csv", DataFrames.DataFrame)
demand = demand_data[:,2:end]
n_hours_data = size(demand,1)
n_loads_data = size(demand,2)

# Calculate peak to average ratio for load demand time series
peak_to_avg_ratio = zeros(n_loads_data,1)
for i_load_data = 1:n_loads_data
    peak_load = maximum(demand[:,i_load_data])
    avg_load = sum(demand[:,i_load_data])/n_hours_data
    peak_to_avg_ratio[i_load_data] = peak_load/avg_load
end

# Write to file
df = DataFrames.DataFrame(peak_to_avg_ratio, :auto)
CSV.write("load_demand_Norway_peak_to_avg_ratio.csv",df)
