function read_res_and_demand_data()

    pv_sicily = Dict()
    open("./test/data/pv_sicily.json") do f
        global pv_sicily
        dicttxt = read(f, String)  # file information to string
        pv_sicily = JSON.parse(dicttxt)  # parse and transform data
    end

    pv_south_central = Dict()
    open("./test/data/pv_south_central.json") do f
        global pv_south_central
        dicttxt = read(f, String)  # file information to string
        pv_south_central = JSON.parse(dicttxt)  # parse and transform data
    end

    wind_sicily = Dict()
    open("./test/data/wind_sicily.json") do f
        global wind_sicily
        dicttxt = read(f, String)  # file information to string
        wind_sicily = JSON.parse(dicttxt)  # parse and transform data
    end


    return pv_sicily, pv_south_central, wind_sicily
end