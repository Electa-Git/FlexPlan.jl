function read_demand_data(year)

    # Read demand CSV files
    demand_north = convert(Matrix, CSV.read(join(["./test/data/demand_north_","$year",".csv"])))[:,3]
    demand_center_north = convert(Matrix, CSV.read(join(["./test/data/demand_center_north_","$year",".csv"])))[:,3]
    demand_center_south = convert(Matrix, CSV.read(join(["./test/data/demand_center_south_","$year",".csv"])))[:,3]
    demand_south = convert(Matrix, CSV.read(join(["./test/data/demand_south_","$year",".csv"])))[:,3]
    demand_sardinia = convert(Matrix, CSV.read(join(["./test/data/demand_sardinia_","$year",".csv"])))[:,3]

    # Convert demand_profile to pu of maxximum
    demand_north_pu = demand_north ./ maximum(demand_north)
    demand_center_north_pu = demand_center_north ./ maximum(demand_center_north)
    demand_south_pu = demand_south ./ maximum(demand_south)
    demand_center_south_pu = demand_center_south ./ maximum(demand_center_south)
    demand_sardinia_pu = demand_sardinia ./ maximum(demand_sardinia)


    return demand_north_pu, demand_center_north_pu, demand_center_south_pu, demand_south_pu, demand_sardinia_pu
end