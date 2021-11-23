using Documenter, FlexPlan

Documenter.makedocs(
    modules = FlexPlan,
    format = Documenter.HTML(),
    sitename = "FlexPlan",
    authors = "Hakan Ergun, Matteo Rossini, Damien Lapage, Iver Bakken Sperstad, Espen Flo Bødal, Marco Rossi, Merkebu Zenebe Degefa, Reinhilde D'hulst",
    pages = [
        "Home" => "index.md"
        "Manual" => [
            "Getting started" => "quickguide.md"
            "Example scripts" => "example_scripts.md"
        ]
        "Library" => [
            "Problem types" => "problem_types.md"
            "Network formulations" => "network_formulations.md"
            "Multi - period, multi-stage modelling" => [
                "Modelling assumptions" => "modeling_assumptions.md"
                "Model dimensions" => "dimensions.md"
            ]
            "Data model" => "data_model.md"
        ]
    ]
)

Documenter.deploydocs(
    repo = "github.com/Electa-Git/FlexPlan.jl.git"
)