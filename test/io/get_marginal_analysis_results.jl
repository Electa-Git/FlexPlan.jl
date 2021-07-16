
function get_ma_results(results::Dict,  utype::String, var::String, time::Int=1)
    rows = []
    for (scen, res) in results
        snap_res = snapshot_utype(res, utype, time)
        colnames = [Symbol(i) for i in select(snap_res,:unit)]
        pushfirst!(colnames, :pval)
        colname_tuple = Tuple(i for i in colnames)
        row_values = select(snap_res,Symbol(var))
        pushfirst!(row_values, scen)
        row = NamedTuple{colname_tuple}(row_values)
        push!(rows, row)
    end
    return sort(table([i for i in rows]))
end