using Documenter, FlexPlan

Documenter.makedocs(
    modules = FlexPlan,
    format = Documenter.HTML(),
    sitename = "FlexPlan",
    authors = "Hakan Ergun, Matteo Rossi, Damien Lapage, Iver Bakken Sperstad, Espen Flo Bødal, Marco Rossi, Merkebu Zenebe Degefa, Reinhilde D'hulst",
    pages = [
        "Home" => "index.md"
        "Manual" => [
            "Getting started" => "quickguide.md"
        ]
        "Library" => [
            "Multi - period, multi-stage modelling" => [
                "Modelling assumptions" => "modeling_assumptions.md"
                "Modelling dimensions" => "dimensions.md"
            ]
        ]
    ]
)

Documenter.deploydocs(
    target = "build",
    repo = "github.com/Electa-Git/FlexPlan.jl.git",
    branch = "gh-pages",
    devbranch = "main",
    versions = ["stable" => "v^", "v#.#"],
    push_preview = false
)