# Data to be added to specific nws only
function add_singular_data!(target::AbstractDict, source::AbstractDict, lookup::AbstractDict, y::Int)
    first_hour_nws = string.(_FP.nw_ids(target, hour=1, year=y))
    last_hour_nws  = string.(_FP.nw_ids(target, hour=_FP.dim_length(target, :hour), year=y))
    for comp in source["scenarioDataInputFile"]["storage"]
        index = lookup["storage"][comp["id"]]
        for s in 1:_FP.dim_length(target, :scenario)
            target["nw"][first_hour_nws[s]]["storage"]["$index"]["energy"] = comp["initEnergy"][s][y]
            target["nw"][last_hour_nws[s]]["storage"]["$index"]["energy"] = comp["finalEnergy"][s][y]
        end
    end
    for cand in source["candidatesInputFile"]["storage"]
        comp = cand["storageData"]
        index = lookup["cand_storage"][comp["id"]]
        for s in 1:_FP.dim_length(target, :scenario)
            target["nw"][first_hour_nws[s]]["ne_storage"]["$index"]["energy"] = comp["initEnergy"][s][y]
            target["nw"][last_hour_nws[s]]["ne_storage"]["$index"]["energy"] = comp["finalEnergy"][s][y]
        end
    end
end
