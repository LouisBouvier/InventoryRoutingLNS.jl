# InventoryRoutingLNS.jl

Core algorithms for solving large-scale multi-attribute IRP.


[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/dev/)
[![Build Status](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

## Note to contributors

The following operations are recommended steps before any commit.
To perform them, you first need to open a Julia REPL in the `InventoryRoutingLNS.jl` folder.
Then, you must activate the `InventoryRoutingLNS` environment by running

```julia
using Pkg
Pkg.activate(".")
```


## Get started

### Continent-scale multi-attribute inventory routing problem
This package aims at solving large-scale multi-attribute inventory routing problems, 
defined in [Solving a Continent-Scale Inventory Routing Problem at Renault](https://arxiv.org/abs/2209.00412). In our setting, routes last several days, and the instances have 15 depots (`Depot`), 600 customers (`Customer`), 30 commodities (`Commodity`) and 21 days horizon 
on average.  

### Solution pipeline

1. To create an IRP `instance` from a folder architecture, we call `read_instance_CSV`.
    This function is designed to browse the `CSV` files and folders and create an `instance` (see `Instance`).
2. A lower bound can be computed on the given instance using a flow relaxation, with `lower_bound`.
3. The initialization + local search algorithm is implemented as `initialization_plus_ls!`.
    It can be applied with two passes, re-estimating the transport costs on the arcs of the commodity flow graphs 
    with a call to `modified_capa_initialization_plus_ls!`.
4. The large neighborhood search can then be applied to improve the initial solution with `LNS!`.

All this pipeline is encapsulated in the `paper_matheuristic!` function.
The algorithm called route-based matheuristic in the paper is implemented as `route_based_matheuristic!`.
Note that in the paper we call LNS the combination of `initialization_plus_ls!` and `LNS!` in our code.


### Reproduce the results of the article

1. Download the dataset of instances available [here](http://cermics.enpc.fr/~parmenta/IRP/instances.zip), unzip it and put it in the `data/` folder of this repository.
2. Run the `main.jl` as is to solve the 71 instances used for the numerical experiments of [Solving a Continent-Scale Inventory Routing Problem at Renault](https://arxiv.org/abs/2209.00412).
