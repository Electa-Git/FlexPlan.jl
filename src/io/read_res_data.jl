function read_res_data(time_series_info; mc = false)

    if mc == false
        year = time_series_info["series_number"]
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
        series_number = time_series_info["series_number"]    
        ts_length = time_series_info["length"]
        n_clusters = time_series_info["n_clusters"]
        method = time_series_info["method"]
        pv_sicily = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_PV_","$series_number",".csv"])))[:,7]
        pv_south_central = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_PV_","$series_number",".csv"])))[:,4]
        wind_sicily = convert(Matrix, CSV.read(join(["./test/data/MC_scenarios/","$n_clusters","_",ts_length,"_clusters",method,"/case_6_wind_","$series_number",".csv"])))[:,7]
    end

    return pv_sicily, pv_south_central, wind_sicily
end