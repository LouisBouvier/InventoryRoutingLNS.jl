```@meta
CurrentModule = InventoryRoutingLNS
```

# InventoryRoutingLNS.jl

Documentation for [InventoryRoutingLNS.jl](https://github.com/LouisBouvier/InventoryRoutingLNS.jl).

## Get started

### Continent-scale multi-attribute inventory routing problem
This package aims at solving large-scale multi-attribute inventory routing problems, 
defined in [Solving a Continent-Scale Inventory Routing Problem at Renault](https://arxiv.org/abs/2209.00412). In our setting, routes last several days, and the instances have 15 depots ([`Depot`](@ref)), 600 customers ([`Customer`](@ref)), 30 commodities ([`Commodity`](@ref)) and 21 days horizon 
on average.  

### Solution pipeline

1. To create an IRP `instance` from a folder architecture, we call [`read_instance_CSV`](@ref).
    This function is designed to browse the `CSV` files and folders and create an `instance` (see [`Instance`](@ref)).
2. A lower bound can be computed on the given instance using a flow relaxation, with [`lower_bound`](@ref).
3. The initialization + local search algorithm is implemented as [`initialization_plus_ls!`](@ref).
    It can be applied with two passes, re-estimating the transport costs on the arcs of the commodity flow graphs 
    with a call to [`modified_capa_initialization_plus_ls!`](@ref).
4. The large neighborhood search can then be applied to improve the initial solution with [`LNS!`](@ref).

All this pipeline is encapsulated in the [`paper_matheuristic!`](@ref) function.
The algorithm called route-based matheuristic in the paper is implemented as [`route_based_matheuristic!`](@ref).
Note that in the paper we call LNS the combination of [`initialization_plus_ls!`](@ref) and [`LNS!`](@ref) in our code.


### Reproduce the results of the article

1. Download the dataset of instances available [here](http://cermics.enpc.fr/~parmenta/IRP/instances.zip), unzip it and put it in the `data/` folder of this repository.
2. Run the `main.jl` as is to solve the 71 instances used for the numerical experiments of [Solving a Continent-Scale Inventory Routing Problem at Renault](https://arxiv.org/abs/2209.00412).

