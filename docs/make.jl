using InventoryRoutingLNS
using Documenter
using Literate

DocMeta.setdocmeta!(
    InventoryRoutingLNS, :DocTestSetup, :(using InventoryRoutingLNS); recursive=true
)

function markdown_title(path)
    title = "?"
    open(path, "r") do file
        for line in eachline(file)
            if startswith(line, '#')
                title = strip(line, [' ', '#'])
                break
            end
        end
    end
    return String(title)
end

pages = [
    "Home" => "index.md",
    "Inventory Routing Problem" => "IRP.md",
    "Input-Output" => "input_output.md",
    "Evaluation" => "evaluation.md",
    "Flows and Graphs" => "flows.md",
    "Utils" => "utils.md",
    "Large Neighborhood Search" => "localsearch.md",
    "Heuristics" => "heuristics.md",
]

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
    pages=pages,
)

deploydocs(; repo="github.com/LouisBouvier/InventoryRoutingLNS.jl", devbranch="main")
