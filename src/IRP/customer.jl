"""
    Customer

A customer demands commodities every day.

In the IRP we plan route deliveries to customers in a centralized manner.

# Fields
- `c::Int`: index of the customer.
- `v::Int`: index of the site (among depots and customers).
- `coordinates::Tuple{Float64,Float64}`: coordinates of the customer.

- `excess_inventory_cost::Vector{Int}`: unit excess inventory cost per commodity.
- `shortage_cost::Vector{Int}`: unit shortage cost per commodity.

- `initial_inventory::Vector{Int}`: initial inventory per commodity.
- `demand::Matrix{Int}`: demand per commodity and day.
- `maximum_inventory::Matrix{Int}`: maximum inventory per commodity and day.

- `quantity_received::Matrix{Int}`: quantity received (with current solution) per commodity and day.
- `inventory::Matrix{Int}`: inventory (with current solution) per commodity and day.

- `commodity_used::Vector{Bool}`: encode the commodities used by the customer.
"""
struct Customer <: Site
    c::Int
    v::Int
    coordinates::Tuple{Float64,Float64}

    excess_inventory_cost::Vector{Int}
    shortage_cost::Vector{Int}
    initial_inventory::Vector{Int}

    demand::Matrix{Int}
    maximum_inventory::Matrix{Int}

    quantity_received::Matrix{Int}
    inventory::Matrix{Int}

    commodity_used::Vector{Bool}

    function Customer(;
        c,
        v,
        coordinates,
        excess_inventory_cost,
        shortage_cost,
        initial_inventory,
        demand,
        maximum_inventory,
    )
        quantity_received = zeros(Int, size(demand))
        inventory = max.(0, initial_inventory .- cumsum(demand; dims=2))
        commodity_used = [
            (initial_inventory[m] > 0 || any(demand[m, :] .> 0)) for
            m in 1:length(initial_inventory)
        ]
        return new(
            c,
            v,
            coordinates,
            excess_inventory_cost,
            shortage_cost,
            initial_inventory,
            demand,
            maximum_inventory,
            quantity_received,
            inventory,
            commodity_used,
        )
    end
end

"""
    Base.show(io::IO, customer::Customer)

Display `customer` in the terminal.
"""
function Base.show(io::IO, customer::Customer)
    str = "Customer $(customer.c)"
    # str *= "\n   Node $(customer.v)"
    # str *= "\n   Coordinates $(customer.coordinates)"
    # str *= "\n   Inventory costs $(customer.excess_inventory_cost)"
    # str *= "\n   Shortage costs $(customer.shortage_cost)"
    # str *= "\n   Initial inventory $(customer.initial_inventory)"
    # str *= "\n   Daily demand $(customer.demand)"
    # str *= "\n   Daily maximum inventory $(customer.maximum_inventory)"
    # str *= "\n   Daily inventory $(customer.inventory)"
    return print(io, str)
end

"""
    Base.copy(customer::Customer)

Copy `customer`.
"""
function Base.copy(customer::Customer)
    return Customer(;
        c=customer.c,
        v=customer.v,
        coordinates=customer.coordinates,
        excess_inventory_cost=customer.excess_inventory_cost,
        shortage_cost=customer.shortage_cost,
        initial_inventory=customer.initial_inventory,
        demand=customer.demand,
        maximum_inventory=customer.maximum_inventory,
    )
end

"""
    renumber(customer::Customer; c::Int, v::Int)

Set `c` and `v` as indices for `customer` over customers and sites respectively.

This can be used when dividing an instance into several smaller ones.
"""
function renumber(customer::Customer; c::Int, v::Int)
    return Customer(;
        c=c,
        v=v,
        coordinates=customer.coordinates,
        excess_inventory_cost=customer.excess_inventory_cost,
        shortage_cost=customer.shortage_cost,
        initial_inventory=customer.initial_inventory,
        demand=customer.demand,
        maximum_inventory=customer.maximum_inventory,
    )
end

"""
    positive_inventory_zero_demand_and_initial_inventory(customer::Customer, m::Int)

Check if `customer` has received some commodity `m` whereas it does not need it.

It is used for feasibility tests in [`feasibility`](@ref).
"""
function positive_inventory_zero_demand_and_initial_inventory(customer::Customer, m::Int)
    min_inventory = minimum(@view customer.inventory[m, :])
    max_demand = maximum(@view customer.demand[m, :])
    init_inventory = customer.initial_inventory[m]
    return (min_inventory > 0) && (max_demand == 0) && (init_inventory == 0)
end

"""
    positive_inventory_zero_demand_and_initial_inventory(customer::Customer)

Check if `customer` has received one type of commodity it does not need.

It is used for feasibility tests in [`feasibility`](@ref).
"""
function positive_inventory_zero_demand_and_initial_inventory(customer::Customer)
    for m in 1:get_M(customer)
        if positive_inventory_zero_demand_and_initial_inventory(customer, m)
            return true
        end
    end
    return false
end
