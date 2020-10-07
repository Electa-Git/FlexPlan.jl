function plot_geo_data(data_in, filename, settings)
    io = open(filename, "w")
    println(io, string("<?xml version=",raw"\"","1.0",raw"\""," encoding=",raw"\"","UTF-8",raw"\"","?>")) #
    println(io, string("<kml xmlns=",raw"\"","http://earth.google.com/kml/2.1",raw"\"",">")) #
    println(io, string("<Document>"))
    draw_order = 1
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
            lat = bus["lat"]
            lon = bus["lon"]
            println(io, string("<Placemark> "));
            println(io, string("<name>Node","$b","</name> "));
            println(io, string("<description>drawOrder=","$draw_order","</description>"));
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
            draw_order = draw_order + 1
        end
    end
    for (b, branch) in data["branch"]
        println(io, string("<Placemark> "));
        println(io, string("<name>Line","$b","</name> "))
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
        println(io, string("<color>#FFF00014</color>")) # blue
        println(io, string("<description>drawOrder=","$draw_order","</description>"))
        println(io, string("<width>3</width>"))
        println(io, string("</LineStyle>"))
        println(io, string("</Style>"))
        println(io, string("</Placemark>"))
    end
    if haskey(data, "ne_branch")
        for (b, branch) in data["ne_branch"]
            println(io, string("<Placemark> "));
            println(io, string("<name>Candidate Line","$b","</name> "))
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
            println(io, string("<color>#FF14F000</color>")) # green
            println(io, string("<description>drawOrder=","$draw_order","</description>"))
            println(io, string("<width>3</width>"))
            println(io, string("</LineStyle>"))
            println(io, string("</Style>"))
            println(io, string("</Placemark>"))
        end
    end
    println(io,  string("</Document>"))
    println(io,  string("</kml>"))
    close(io)
end