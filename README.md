# InventoryRoutingLNS

Core algorithms for solving large-scale multi-attribute IRP.


[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://LouisBouvier.github.io/InventoryRoutingLNS.jl/dev/)
[![Build Status](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/LouisBouvier/InventoryRoutingLNS.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/LouisBouvier/InventoryRoutingLNS.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

## Note to contributors

The following operations are recommended steps before any commit.
To perform them, you first need to open a Julia REPL in the `InventoryRoutingLNS` folder.
Then, you must activate the `InventoryRoutingLNS` environment by running

```julia
using Pkg
Pkg.activate(".")
```

## Documentation

You can build the documentation locally with this command:

```julia
Pkg.activate("docs")
include("docs/make.jl")
```

Then, open `docs/build/index.html` in your favorite browser.
