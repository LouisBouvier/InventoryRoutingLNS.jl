module InventoryRoutingLNS

using Combinatorics
using Clp
using CSV
using DataDeps
using DataFrames
using Distributed
using Gurobi
using IterTools
using JSON
using JuMP
using Graphs
using LinearAlgebra
using Plots
using ProgressMeter
using Random
using SparseArrays
using ZipFile

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
export read_instance_CSV, read_instance_ZIP, read_solution
export paper_matheuristic!, route_based_matheuristic!
export modified_capa_initialization_plus_ls!, multi_depot_local_search!
export analyze_solution, analyze_instance

# Data dependencies
function __init__()
    DataDeps.register(
        DataDep(
            "IRP-instances",
            """
            TODO: description, authors, citation, copyright, etc.
            """,
            "http://cermics.enpc.fr/~parmenta/IRP/instances.zip",
        ),
    )
    DataDeps.register(
        DataDep(
            "IRP-solutions",
            """
            TODO: description, authors, citation, copyright, etc.
            """,
            "http://cermics.enpc.fr/~parmenta/IRP/solutions.zip",
        ),
    )
    return nothing
end

end
