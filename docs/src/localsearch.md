# Large neighborhood search

## Small neighborhoods

### TSP generalized

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/TSP_neighborhoods.jl",
"local_search/route_single_optim.jl",
"local_search/route_delete.jl"]
```

### Single-depot SDVRP generalized

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/neighborhood_pruning.jl",
"local_search/route_exchange.jl",
"local_search/route_merge_multiday.jl",
"local_search/route_merge.jl"]
```

### Multi-depot SDVRP generalized

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/IRP_multiday_neighborhoods.jl",
"local_search/IRP_neighborhoods.jl"]
```
## Large neighborhoods 

### Customer reinsertion

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/ruin_recreate_customer.jl"]
```

### Commodity reinsertion

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/ruin_recreate_commodity.jl"]
```
## Algorithms for exploration

```@autodocs
Modules = [InventoryRoutingLNS]
Pages = ["local_search/local_search.jl"]
```