function read_res_data(year; mc = false)

    if mc == false
        pv_sicily = Dict()
        open(join(["./test/data/pv_sicily_","$year",".json"])) do f
            dicttxt = read(f, String)  # file information to string
            pv_sicily = JSON.parse(dicttxt)  # parse and transform data
        end

        pv_south_central = Dict()
        open(join(["./test/data/pv_south_central_","$year",".json"])) do f
            dicttxt = read(f, String)  # file information to string
            pv_south_central = JSON.parse(dicttxt)  # parse and transform data
        end

        wind_sicily = Dict()
        open(join(["./test/data/wind_sicily_","$year",".json"])) do f
            dicttxt = read(f, String)  # file information to string
            wind_sicily = JSON.parse(dicttxt)  # parse and transform data
        end
    else
        pv_sicily = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/35_yearly_clusters/case_6_PV_","$year",".csv"]),DataFrames.DataFrame))[:,7]
        pv_south_central = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/35_yearly_clusters/case_6_PV_","$year",".csv"]),DataFrames.DataFrame))[:,4]
        wind_sicily = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/35_yearly_clusters/case_6_wind_","$year",".csv"]),DataFrames.DataFrame))[:,7]
    end

    return pv_sicily, pv_south_central, wind_sicily
end