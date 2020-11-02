function read_res_data(year)

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

    return pv_sicily, pv_south_central, wind_sicily
end