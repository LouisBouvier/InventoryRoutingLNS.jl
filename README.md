# InventoryRoutingLNS.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/dev/)
[![Build Status](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.8178634.svg)](https://doi.org/10.5281/zenodo.8178634)

Large Neighborhood Search for solving large-scale multi-attribute Inventory Routing Problems.

## Context

This package tackles large-scale multi-attribute inventory routing problems, as defined in our paper

> [Solving a Continent-Scale Inventory Routing Problem at Renault](https://arxiv.org/abs/2209.00412)

In our setting, routes last several days, and the instances have 15 depots, 600 customers, 30 commodities and a 21-day horizon on average.

## Getting started

For any question on a specific function, check out the [package documentation](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/stable/).

### Solution pipeline

1. To create an IRP instance from a folder architecture, we call `read_instance_CSV`. This function is designed to browse multiple CSV files and combine them into an `Instance` object..
2. A lower bound can be computed on the given instance using a flow relaxation, with `lower_bound`.
3. The initialization + local search algorithm is implemented as `initialization_plus_ls!`. It can be applied with two passes, re-estimating the transport costs on the arcs of the commodity flow graphs with a call to `modified_capa_initialization_plus_ls!`.
4. The large neighborhood search can then used applied to improve the initial solution with `LNS!`.

The complete pipeline is encapsulated in the `paper_matheuristic!` function.
The algorithm called "route-based matheuristic" in the paper is implemented as `route_based_matheuristic!`.
Note that what we call "LNS" in our paper corresponds to the combination of `initialization_plus_ls!` and `LNS!` in our code.

### Reproducing our results

First, you need to clone the repository and open a Julia REPL at its root.
Then, run the following commands:

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
include("test/main.jl")
```

This will solve the 71 instances used for the numerical experiments in our paper. Beware that this process is extremely time-consuming, that is why we included a shorter test version which you can try with

```julia
include("test/run_example.jl")
```

The Renault problem instances will be automatically downloaded from <https://zenodo.org/record/8177237> and placed in a folder called `.julia/datadeps/`.
You can then compare the solutions you obtain with the ones available at <https://zenodo.org/record/8177271>.
