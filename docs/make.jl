using Documenter, FlexPlan

makedocs(
    modules = [FlexPlan],
    sitename = "FlexPlan",
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

deploydocs(
    repo = "github.com/Electa-Git/FlexPlan.jl.git"
)
