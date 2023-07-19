"""
    Depot

A depot releases commodities every day.

In the IRP we plan route deliveries starting at depots in a centralized manner.

# Fields
- `d::Int`: index of the depot.
- `v::Int`: index of the site (among depots and customers).
- `coordinates::Tuple{Float64,Float64}`: coordinates of the depot.

- `excess_inventory_cost::Vector{Int}`: unit excess inventory cost per commodity.

- `initial_inventory::Vector{Int}`: initial inventory per commodity.
- `production::Matrix{Int}`: release per commodity and day.
- `maximum_inventory::Matrix{Int}`: maximum inventory per commodity and day.

- `quantity_sent::Matrix{Int}`: quantity sent (with current solution) per commodity and day.
- `inventory::Matrix{Int}`: inventory (with current solution) per commodity and day.

- `commodity_used::Vector{Bool}`: encode the commodities used by the depot.
"""
struct Depot <: Site
    d::Int
    v::Int
    coordinates::Tuple{Float64,Float64}

    excess_inventory_cost::Vector{Int}
    initial_inventory::Vector{Int}

    production::Matrix{Int}
    maximum_inventory::Matrix{Int}

    quantity_sent::Matrix{Int}
    inventory::Matrix{Int}

    commodity_used::Vector{Bool}

    function Depot(;
        d,
        v,
        coordinates,
        excess_inventory_cost,
        initial_inventory,
        production,
        maximum_inventory,
    )
        quantity_sent = zeros(Int, size(production))
        inventory = initial_inventory .+ cumsum(production; dims=2)
        commodity_used = [
            (initial_inventory[m] > 0 || any(production[m, :] .> 0)) for
            m in 1:length(initial_inventory)
        ]
        return new(
            d,
            v,
            coordinates,
            excess_inventory_cost,
            initial_inventory,
            production,
            maximum_inventory,
            quantity_sent,
            inventory,
            commodity_used,
        )
    end
end

"""
    Base.show(io::IO, depot::Depot)

Display `depot` in the terminal.
"""
function Base.show(io::IO, depot::Depot)
    str = "Depot $(depot.d)"
    # str *= "\n   Node $(depot.v)"
    # str *= "\n   Coordinates $(depot.coordinates)"
    # str *= "\n   Inventory costs $(depot.excess_inventory_cost)"
    # str *= "\n   Initial inventory $(depot.initial_inventory)"
    # str *= "\n   Daily production $(depot.production)"
    # str *= "\n   Daily maximum inventory $(depot.maximum_inventory)"
    # str *= "\n   Daily inventory $(depot.inventory)"
    return print(io, str)
end

"""
    Base.copy(depot::Depot)

Copy `depot`.
"""
function Base.copy(depot::Depot)
    return Depot(;
        d=depot.d,
        v=depot.v,
        coordinates=depot.coordinates,
        excess_inventory_cost=depot.excess_inventory_cost,
        initial_inventory=depot.initial_inventory,
        production=depot.production,
        maximum_inventory=depot.maximum_inventory,
    )
end

"""
    renumber(depot::Depot; d::Int, v::Int)

Set `d` and `v` as indices for `depot` over depots and sites respectively.

This can be used when dividing an instance into several smaller ones.
"""
function renumber(depot::Depot; d::Int, v::Int)
    return Depot(;
        d=d,
        v=v,
        coordinates=depot.coordinates,
        excess_inventory_cost=depot.excess_inventory_cost,
        initial_inventory=depot.initial_inventory,
        production=depot.production,
        maximum_inventory=depot.maximum_inventory,
    )
end
