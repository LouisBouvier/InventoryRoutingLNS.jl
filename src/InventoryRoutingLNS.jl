module InventoryRoutingLNS

using Combinatorics
using Clp
using CSV
using DataDeps
using DataFrames
using Distributed
using Graphs
using Gurobi
using GZip
using HiGHS
using IterTools
using JSON
using JuMP
using LinearAlgebra
using Plots
using ProgressMeter
using Random
using SparseArrays
using Tar

using DataStructures: OrderedDict

include("IRP/commodity.jl")
include("IRP/site.jl")
include("IRP/depot.jl")
include("IRP/customer.jl")
include("IRP/route.jl")
include("IRP/solution.jl")
include("IRP/solution_simple.jl")
include("IRP/solution_structured.jl")
include("IRP/instance.jl")
include("IRP/analysis.jl")
include("input_output/import.jl")
include("input_output/export.jl")
include("evaluation/inventory.jl")
include("evaluation/feasibility.jl")
include("evaluation/cost.jl")
include("flows/graph_format.jl")
include("flows/truck_graph.jl")
include("flows/truck_graph_single_customer.jl")
include("flows/commodity_graph.jl")
include("flows/commodity_graph_single_customer.jl")
include("local_search/route_single_optim.jl")
include("local_search/TSP_neighborhoods.jl")
include("local_search/route_merge.jl")
include("local_search/route_merge_multiday.jl")
include("local_search/route_exchange.jl")
include("local_search/route_delete.jl")
include("local_search/neighborhood_pruning.jl")
include("local_search/IRP_neighborhoods.jl")
include("local_search/IRP_multiday_neighborhoods.jl")
include("local_search/ruin_recreate_customer.jl")
include("local_search/ruin_recreate_commodity.jl")
include("local_search/local_search.jl")
include("heuristics/delays_from_instance.jl")
include("heuristics/relaxation.jl")
include("heuristics/bin_packing.jl")
include("heuristics/greedy_heuristic.jl")
include("heuristics/matheuristic.jl")
include("heuristics/fill_fixed_routes.jl")
include("heuristics/benchmark_heuristic.jl")
include("utils/combinatorics.jl")
include("utils/manage_time.jl")
include("analysis/analyze_solutions.jl")
include("analysis/analyze_instances.jl")

## Matheuristic
export decompress_dataset
export read_instance_CSV, read_solution
export paper_matheuristic!, route_based_matheuristic!
export modified_capa_initialization_plus_ls!, multi_depot_local_search!
export analyze_solution, analyze_instance

# Data dependencies
function __init__()
    DataDeps.register(
        DataDep(
            "IRP-instances",
            """
            This dataset of inventory routing instances is a fruit of our partnership 
            between Renault Group and the CERMICS laboratory at Ecole des Ponts. 
            Those instances are continent-scale with hundreds of customers, 21 days horizon, 
            and 15 depots on average. Routes can last several days (continuous-time), 
            and 30 types of commodities are involved, leading to bin packing problems 
            when filling trucks. In our paper "Solving a Continent-Scale Inventory Routing
            Problem at Renault" we introduce a new large neighborhood search to solve 
            those instances. We hope that sharing them publicly will motivate research on 
            real-world and large-scale inventory routing. Environmental and economical 
            impacts at stake are substantial.
            To cite this dataset: 10.5281/zenodo.8177237.
            Louis Bouvier, Guillaume Dalle, Axel Parmentier, Thibaut Vidal.
            """,
            "https://zenodo.org/record/8177237/files/instances.tar.gz?download=1";
            post_fetch_method=(file -> decompress_dataset(file, "instances")),
        ),
    )
    DataDeps.register(
        DataDep(
            "IRP-solutions",
            """
            This dataset of inventory routing solutions is a fruit of our partnership
            between Renault Group and the CERMICS laboratory at Ecole des Ponts. 
            The related instances (also publicly available) are continent-scale with 
            hundreds of customers, 21 days horizon, and 15 depots on average. 
            Routes can last several days (continuous-time), and 30 types of commodities
            are involved, leading to bin packing problems when filling trucks. 
            In our paper "Solving a Continent-Scale Inventory Routing Problem at Renault"
            we introduce a new large neighborhood search to solve those instances. 
            This dataset contains the solutions provided both by our algorithm and 
            by a benchmark we implement, as shown in the computational experiments section
            of our paper. We hope that sharing them publicly will motivate research 
            on real-world and large-scale inventory routing. Environmental and economical
            impacts at stake are substantial.
            To cite this dataset: 10.5281/zenodo.8177271.
            Louis Bouvier, Guillaume Dalle, Axel Parmentier, Thibaut Vidal.
            """,
            "https://zenodo.org/record/8177271/files/solutions.tar.gz?download=1";
            post_fetch_method=(file -> decompress_dataset(file, "solutions")),
        ),
    )
    return nothing
end

end
