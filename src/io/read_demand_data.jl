function read_demand_data(time_series_info; mc = false)

    if mc == false
        series_number = time_series_info["series_number"]
        # Read demand CSV files
        demand_north = convert(Matrix, CSV.read(join(["./test/data/demand_north_","$series_number",".csv"])))[:,3]
        demand_center_north = convert(Matrix, CSV.read(join(["./test/data/demand_center_north_","$series_number",".csv"])))[:,3]
        demand_center_south = convert(Matrix, CSV.read(join(["./test/data/demand_center_south_","$series_number",".csv"])))[:,3]
        demand_south = convert(Matrix, CSV.read(join(["./test/data/demand_south_","$series_number",".csv"])))[:,3]
        demand_sardinia = convert(Matrix, CSV.read(join(["./test/data/demand_sardinia_","$series_number",".csv"])))[:,3]

        # Convert demand_profile to pu of maxximum
        demand_north_pu = demand_north ./ maximum(demand_north)
        demand_center_north_pu = demand_center_north ./ maximum(demand_center_north)
        demand_south_pu = demand_south ./ maximum(demand_south)
        demand_center_south_pu = demand_center_south ./ maximum(demand_center_south)
        demand_sardinia_pu = demand_sardinia ./ maximum(demand_sardinia)
    else
        series_number = time_series_info["series_number"]    
        ts_length = time_series_info["length"]
        n_clusters = time_series_info["n_clusters"]
        method = time_series_info["method"]
        demand_north_pu = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_demand_","$series_number",".csv"])))[:,3]
        demand_center_north_pu = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_demand_","$series_number",".csv"])))[:,2]
        demand_center_south_pu = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_demand_","$series_number",".csv"])))[:,4]
        demand_south_pu = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_demand_","$series_number",".csv"])))[:,5]
        demand_sardinia_pu = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_demand_","$series_number",".csv"])))[:,6]
    end

    return demand_north_pu, demand_center_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu
end