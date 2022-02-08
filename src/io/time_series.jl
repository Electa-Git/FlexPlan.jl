"""
    make_time_series(data, number_of_periods; loadprofile, genprofile)

Make a time series dict from profile matrices, to be used in `make_multinetwork`.

`number_of_periods` is by default the number of networks specified in `data`.
Profile matrices must have `number_of_periods` rows and one column for each component (load
or generator).

# Arguments
- `data`: a multinetwork data dictionary;
- `number_of_periods = dim_length(data)`;
- `loadprofile = ones(number_of_periods,length(data["load"]))`;
- `genprofile = ones(number_of_periods,length(data["gen"])))`.
"""
function make_time_series(data::Dict{String,Any}, number_of_periods::Int = dim_length(data); loadprofile = ones(number_of_periods,length(data["load"])), genprofile = ones(number_of_periods,length(data["gen"])))
    if size(loadprofile) ≠ (number_of_periods, length(data["load"]))
        right_size = (number_of_periods, length(data["load"]))
        Memento.error(_LOGGER, "Size of loadprofile matrix must be $right_size, found $(size(loadprofile)) instead.")
    end
    if size(genprofile) ≠ (number_of_periods, length(data["gen"]))
        right_size = (number_of_periods, length(data["gen"]))
        Memento.error(_LOGGER, "Size of genprofile matrix must be $right_size, found $(size(genprofile)) instead.")
    end
    return Dict{String,Any}(
        "load" => Dict{String,Any}(l => Dict("pd" => load["pd"] .* loadprofile[:, parse(Int, l)]) for (l,load) in data["load"]),
        "gen" => Dict{String,Any}(g => Dict("pmax" => gen["pmax"] .* genprofile[:, parse(Int, g)]) for (g,gen) in data["gen"]),
    )
end
