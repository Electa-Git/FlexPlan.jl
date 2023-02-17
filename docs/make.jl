using Documenter, FlexPlan

Documenter.makedocs(
    modules = [FlexPlan],
    format = Documenter.HTML(),
    sitename = "FlexPlan",
    authors = "Hakan Ergun, Matteo Rossini, Damien Lepage, Iver Bakken Sperstad, Espen Flo Bødal, Marco Rossi, Merkebu Zenebe Degefa, Reinhilde D'Hulst",
    pages = [
        "Home" => "index.md"
        "Manual" => [
            "Installation" => "installation.md"
            "Examples" => "examples.md"
            "Tutorial" => "tutorial.md"
        ]
        "Library" => [
            "Problem types" => "problem_types.md"
            "Network formulations" => "network_formulations.md"
            "Multiperiod, multistage modelling" => [
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