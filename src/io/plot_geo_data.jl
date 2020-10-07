function plot_geo_data(data_in, filename, settings; solution = Dict())
    io = open(filename, "w")
    println(io, string("<?xml version=",raw"\"","1.0",raw"\""," encoding=",raw"\"","UTF-8",raw"\"","?>")) #
    println(io, string("<kml xmlns=",raw"\"","http://earth.google.com/kml/2.1",raw"\"",">")) #
    println(io, string("<Document>"))
    draw_order = 1
    if haskey(solution, "solution")
        if haskey(solution["solution"],"nw")
            sol = solution["solution"]["nw"]["1"]
        else
            sol = solution["solution"]
        end
    end
    if haskey(data_in, "solution")
        if haskey(data_in, "nw")
            data = data_in["solution"]["nw"]["1"]
        else
            data = data_in["solution"]
        end
    else
        if haskey(data_in, "nw")
            data = data_in["nw"]["1"]
        else
            data = data_in
        end
    end
    if settings["add_nodes"] == true
        for (b, bus) in data["bus"]
            plot_bus(io, bus, b)
        end
    end
    for (b, branch) in data["branch"]
        plot_branch(io, branch, b, data; color_in = "blue")
    end
    if haskey(data, "ne_branch")
        for (b, branch) in data["ne_branch"]
            if haskey(settings, "plot_solution_only")
                if  sol["ne_branch"]["$b"]["built"] == 1
                    plot_branch(io, branch, b, data; color_in = "blue", name = "Candidate Line")
                end
            else
                plot_branch(io, branch, b, data; color_in = "green", name = "Candidate Line")
            end
        end
    end
    if haskey(data, "branchdc")
       for (bdc, branchdc) in data["branchdc"]
            plot_dc_branch(io, branchdc, bdc, data; color_in = "yellow")
       end
    end

    if haskey(data, "branchdc_ne")
        for (bdc, branchdc) in data["branchdc_ne"]
            if haskey(settings, "plot_solution_only")
                if  sol["branchdc_ne"]["$bdc"]["isbuilt"] == 1
                    plot_dc_branch(io, branchdc, bdc, data; color_in = "yellow", name = "Candidate DC Line")
                end
            else
                plot_dc_branch(io, branchdc, bdc, data; color_in = "red", name = "Candidate DC Line")
            end
        end
     end

     if haskey(data, "convdc")
        for (cdc, convdc) in data["convdc"]
             plot_dc_conv(io, convdc, cdc, data; color_in = "yellow")
        end
     end


    if haskey(data, "convdc_ne")
        for (cdc, convdc) in data["convdc_ne"]
            if haskey(settings, "plot_solution_only")
                if  sol["convdc_ne"]["$cdc"]["isbuilt"] == 1
                    plot_dc_conv(io, convdc, cdc, data; color_in = "yellow", name = "Candidate DC converter")
                end
            else
                plot_dc_conv(io, convdc, cdc, data; color_in = "red", name = "Candidate DC converter")
            end
        end
     end

    println(io,  string("</Document>"))
    println(io,  string("</kml>"))
    close(io)
end


function plot_bus(io, bus, b)
    lat = bus["lat"]
    lon = bus["lon"]
    println(io, string("<Placemark> "));
    println(io, string("<name>Node","$b","</name> "));
    #println(io, string("<description>drawOrder=","$draw_order","</description>"));
    println(io, string("<ExtendedData> "));
    println(io, string("<SimpleData name=",raw"\"","Name",raw"\"",">Node 1</SimpleData>"));
    println(io, string("<SimpleData name=",raw"\"","Description",raw"\"","></SimpleData> "));
    println(io, string("<SimpleData name=",raw"\"","Latitude",raw"\"",">","$lat","</SimpleData>"));
    println(io, string("<SimpleData name=",raw"\"","Longitude",raw"\"",">","$lon","</SimpleData>"));
    println(io, string("<SimpleData name=",raw"\"","Icon",raw"\"","></SimpleData> "));
    println(io, string("</ExtendedData>"));
    println(io, string("<Point> "));
    println(io, string("<coordinates>","$lon",",","$lat",",","0","</coordinates>"));
    println(io, string("</Point> "));
    println(io, string("<Style id=",raw"\"","downArrowIcon",raw"\"",">"));
    println(io, string("<IconStyle> "));
    println(io, string("<Icon> "));
    println(io, string("<href>http://maps.google.com/mapfiles/kml/shapes/placemark_circle_highlight.png</href>"));
    println(io, string("</Icon> "));
    println(io, string("</IconStyle> "));
    println(io, string("</Style> "));
    println(io, string("</Placemark> "));
    return io
end

function plot_branch(io, branch, b, data; color_in = "blue", name = "Line")
    println(io, string("<Placemark> "));
    println(io, string("<name>",name,"$b","</name> "))
    println(io, string("<LineString>"))
    println(io, string("<tessellate>1</tessellate>"))
    println(io, string("<coordinates>"))
    fbus = branch["f_bus"]
    tbus = branch["t_bus"]
    fbus_lat = data["bus"]["$fbus"]["lat"]
    fbus_lon = data["bus"]["$fbus"]["lon"]
    tbus_lat = data["bus"]["$tbus"]["lat"]
    tbus_lon = data["bus"]["$tbus"]["lon"]
    println(io, string("$fbus_lon",",","$fbus_lat","0"))
    println(io, string("$tbus_lon",",","$tbus_lat","0"))
    println(io, string("</coordinates>"))
    println(io, string("</LineString>"))
    println(io, string("<Style>"))
    println(io, string("<LineStyle>"))
    if color_in == "green"
        color = "#FF14F000"
    else
        color = "#FFF00014"
    end
    println(io, string("<color>",color,"</color>"))
    #println(io, string("<description>drawOrder=","$draw_order","</description>"))
    println(io, string("<width>3</width>"))
    println(io, string("</LineStyle>"))
    println(io, string("</Style>"))
    println(io, string("</Placemark>"))
    return io
end


function plot_dc_branch(io, branch, b, data; color_in = "yellow", name = "DC Line")
    println(io, string("<Placemark> "));
    println(io, string("<name>",name,"$b","</name> "))
    println(io, string("<LineString>"))
    println(io, string("<tessellate>1</tessellate>"))
    println(io, string("<coordinates>"))
    fbus = branch["fbusdc"]
    tbus = branch["tbusdc"]
    if haskey(data, "convdc")
        for (c, conv) in data["convdc"]
            if conv["busdc_i"] == fbus
                fbus = conv["busac_i"]
            end
            if conv["busdc_i"] == tbus
                tbus = conv["busac_i"]
            end
        end
    end
    if haskey(data, "convdc_ne")
        for (c, conv) in data["convdc_ne"]
            if conv["busdc_i"] == fbus
                fbus = conv["busac_i"]
            end
            if conv["busdc_i"] == tbus
                tbus = conv["busac_i"]
            end
        end
    end
    fbus_lat = data["bus"]["$fbus"]["lat"]
    fbus_lon = data["bus"]["$fbus"]["lon"]
    tbus_lat = data["bus"]["$tbus"]["lat"]
    tbus_lon = data["bus"]["$tbus"]["lon"]
    println(io, string("$fbus_lon",",","$fbus_lat","0"))
    println(io, string("$tbus_lon",",","$tbus_lat","0"))
    println(io, string("</coordinates>"))
    println(io, string("</LineString>"))
    println(io, string("<Style>"))
    println(io, string("<LineStyle>"))
    if color_in == "red"
        color = "#FF1400FF"
    else
        color = "#FF14F0FF"
    end
    println(io, string("<color>",color,"</color>"))
    #println(io, string("<description>drawOrder=","$draw_order","</description>"))
    println(io, string("<width>3</width>"))
    println(io, string("</LineStyle>"))
    println(io, string("</Style>"))
    println(io, string("</Placemark>"))
    return io
end


function plot_dc_conv(io, conv, c, data; color_in = "yellow", name = "DC Converter")
    println(io, string("<Placemark> "));
    println(io, string("<name>",name,"$c","</name> "))
    println(io, string("<LineString>"))
    println(io, string("<tessellate>1</tessellate>"))
    println(io, string("<coordinates>"))
    bus = conv["busac_i"]
    bus_lat = data["bus"]["$bus"]["lat"]
    bus_lon = data["bus"]["$bus"]["lon"]
    bus_lon1 = bus_lon + 0.05
    bus_lat1 = bus_lat + 0.05
    println(io, string("$bus_lon1",",","$bus_lat1","0"))
    bus_lon1 = bus_lon + 0.05
    bus_lat1 = bus_lat - 0.05
    println(io, string("$bus_lon1",",","$bus_lat1","0"))
    bus_lon1 = bus_lon - 0.05
    bus_lat1 = bus_lat - 0.05
    println(io, string("$bus_lon1",",","$bus_lat1","0"))
    bus_lon1 = bus_lon - 0.05
    bus_lat1 = bus_lat + 0.05
    println(io, string("$bus_lon1",",","$bus_lat1","0"))
    bus_lon1 = bus_lon + 0.05
    bus_lat1 = bus_lat + 0.05
    println(io, string("$bus_lon1",",","$bus_lat1","0"))
    println(io, string("</coordinates>"))
    println(io, string("</LineString>"))
    println(io, string("<Style>"))
    println(io, string("<LineStyle>"))
    if color_in == "red"
        color = "#FF1400FF"
    else
        color = "#FF14F0FF"
    end
    println(io, string("<color>",color,"</color>"))
    #println(io, string("<description>drawOrder=","$draw_order","</description>"))
    println(io, string("<width>3</width>"))
    println(io, string("</LineStyle>"))
    println(io, string("</Style>"))
    println(io, string("</Placemark>"))
    return io
end