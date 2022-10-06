using InventoryRoutingLNS
using Documenter

DocMeta.setdocmeta!(InventoryRoutingLNS, :DocTestSetup, :(using InventoryRoutingLNS); recursive=true)

makedocs(;
    modules=[InventoryRoutingLNS],
    authors="Louis Bouvier, Guillaume Dalle, Axel Parmentier, Thibaut Vidal",
    repo="https://github.com/LouisBouvier/InventoryRoutingLNS.jl/blob/{commit}{path}#{line}",
    sitename="InventoryRoutingLNS.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://LouisBouvier.github.io/InventoryRoutingLNS.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/LouisBouvier/InventoryRoutingLNS.jl",
    devbranch="main",
)
