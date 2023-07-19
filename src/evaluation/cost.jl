## Costs routes

"""
    compute_stops_cost(route::Route, instance::Instance)

Compute the stops' cost of `route`.

The stops' cost is defined as the product of the number of stops 
and the unit cost of a stop of `instance` . 
"""
function compute_stops_cost(route::Route, instance::Instance)
    return instance.stop_cost * get_nb_stops(route)
end

"""
    compute_km_cost(route::Route, instance::Instance)

Compute the kilometers' cost of `route`.

The kilometers' cost is defined as the product of the number of km 
travelled and the unit km cost of `instance`. 
"""
function compute_km_cost(route::Route, instance::Instance)
    return instance.km_cost * compute_nb_km(route, instance)
end

"""
    compute_route_cost(route::Route, instance::Instance)

Compute the routing cost of `route`.

The routing cost is defined as the sum of the kilometers' cost, the stops' cost 
and the vehicle cost. 
"""
function compute_route_cost(route::Route, instance::Instance)
    return (
        get_vehicle_cost(instance) +
        compute_stops_cost(route, instance) +
        compute_km_cost(route, instance)
    )
end

## Cost depots

"""
    compute_inventory_cost(depot::Depot, t::Int, ms::Vector{Int} = collect(1:get_M(depot)))

Compute the excess inventory cost of `depot` on day `t` for the commodities indexed by `ms`.

The excess inventory cost on day `t` for commodity `m` is defined as the product of the 
number of commodities of type `m` above the maximum inventory and the unit excess cost. 
The unit excess cost is defined for each depot on each day for each commodity. 
"""
function compute_inventory_cost(
    depot::Depot, t::Int, ms::Vector{Int}=collect(1:get_M(depot))
)
    cost = 0
    for m in ms
        cost +=
            depot.excess_inventory_cost[m] *
            max(0, depot.inventory[m, t] - depot.maximum_inventory[m, t])
    end
    return cost
end

"""
    compute_inventory_cost(depot::Depot, 
                            ms::Vector{Int} = collect(1:get_M(depot)), 
                            ts::Vector{Int} = collect(1:get_T(depot))
    )

Compute the excess inventory cost of `depot` on the period `ts` for the commodities indexed by `ms`.

We sum the inventory costs of the commodities indexed by `ms` on the days `ts`. 
"""
function compute_inventory_cost(
    depot::Depot,
    ms::Vector{Int}=collect(1:get_M(depot)),
    ts::Vector{Int}=collect(1:get_T(depot)),
)
    return sum(compute_inventory_cost(depot, t, ms) for t in ts)
end

## Cost customers

"""
    compute_inventory_cost(customer::Customer, t::Int, ms::Vector{Int} = collect(1:get_M(customer)))

Compute the excess inventory cost of `customer` on day `t` for the commodities indexed by `ms`.

The excess inventory cost on day `t` for commodity `m` is defined as the product of the 
number of commodities of type `m` above the maximum inventory and the unit excess cost. 
The unit excess cost is defined for each customer on each day for each commodity. 
"""
function compute_inventory_cost(
    customer::Customer, t::Int, ms::Vector{Int}=collect(1:get_M(customer))
)
    cost = 0
    for m in ms
        cost +=
            customer.excess_inventory_cost[m] *
            max(0, customer.inventory[m, t] - customer.maximum_inventory[m, t])
    end
    return cost
end

"""
    compute_inventory_cost(customer::Customer, 
                            ms::Vector{Int} = collect(1:get_M(customer)), 
                            ts::Vector{Int} = collect(1:get_T(customer))
    )

Compute the excess inventory cost of `customer` on the period `ts` for the commodities indexed by `ms`.

We sum the inventory costs of the commodities indexed by `ms` on the days `ts`.
"""
function compute_inventory_cost(
    customer::Customer,
    ms::Vector{Int}=collect(1:get_M(customer)),
    ts::Vector{Int}=collect(1:get_T(customer)),
)
    return sum(compute_inventory_cost(customer, t, ms) for t in ts)
end

"""
    compute_shortage_cost(customer::Customer, t::Int, ms::Vector{Int} = collect(1:get_M(customer)))

Compute the shortage cost of `customer` on day `t` for the commodities indexed by `ms`.

The shortage cost on day `t` for commodity `m` is defined as the product of the 
number of commodities of type `m` below the minimum inventory on the morning of day `t` 
(thus inventory of the previous evening less the demand on day `t`) and the unit shortage cost. 
The unit shortage cost is defined for each customer for each commodity. 
"""
function compute_shortage_cost(
    customer::Customer, t::Int, ms::Vector{Int}=collect(1:get_M(customer))
)
    cost = 0
    for m in ms
        cost +=
            customer.shortage_cost[m] * max(
                0,
                customer.demand[m, t] -
                (t == 1 ? customer.initial_inventory[m] : customer.inventory[m, t - 1]),
            )
    end
    return cost
end

"""
    compute_shortage_cost(customer::Customer, 
                            ms::Vector{Int} = collect(1:get_M(customer)), 
                            ts::Vector{Int} = collect(1:get_T(customer))
    )

Compute the shortage cost of `customer` on the period `ts` for the commodities indexed by `ms`.

We sum the shortage costs of the commodities indexed by `ms` on the days `ts`.
"""
function compute_shortage_cost(
    customer::Customer,
    ms::Vector{Int}=collect(1:get_M(customer)),
    ts::Vector{Int}=collect(1:get_T(customer)),
)
    return sum(compute_shortage_cost(customer, t, ms) for t in ts)
end

## Total cost

"""
    compute_undetailed_cost(instance::Instance;
                            ds::Vector{Int} = collect(1:instance.D),
                            cs::Vector{Int} = collect(1:instance.C),
                            ms::Vector{Int} = collect(1:instance.M),
                            ts::Vector{Int} = collect(1:instance.T),
                            solution::Solution = instance.solution,
    )   

Compute the total cost of the `solution` of `instance`.

The total cost is defined as the sum of the routing costs, excess inventory
costs at the depots and customers, and shortage costs at the customers.
Notably for neighborhoods, when computing the cost, we may want to restrict the `instance` to:
- the depots indexed by `ds`.
- the customers indexed by `cs`.
- the commodities indexed by `ms`.
- the days `ts`. 
"""
function compute_undetailed_cost(
    instance::Instance;
    ds::Vector{Int}=collect(1:(instance.D)),
    cs::Vector{Int}=collect(1:(instance.C)),
    ms::Vector{Int}=collect(1:(instance.M)),
    ts::Vector{Int}=collect(1:(instance.T)),
    solution::Solution=instance.solution,
)
    cost = 0
    for depot in instance.depots[ds]
        cost += compute_inventory_cost(depot, ms, ts)
    end
    for customer in instance.customers[cs]
        cost += compute_inventory_cost(customer, ms, ts)
        cost += compute_shortage_cost(customer, ms, ts)
    end
    for route in list_routes(solution)
        cost += compute_route_cost(route, instance)
    end
    return cost
end

"""
    compute_detailed_cost(instance::Instance;
                            ds::Vector{Int} = collect(1:instance.D),
                            cs::Vector{Int} = collect(1:instance.C),
                            ms::Vector{Int} = collect(1:instance.M),
                            ts::Vector{Int} = collect(1:instance.T),
                            solution::Solution = instance.solution,
    )

Compute the total cost of the `solution` of `instance` and print detailed results.

Same principle as for [`compute_undetailed_cost`](@ref) but with statistics on the 
decomposition of the cost. It may be useful for tests and investigation.
"""
function compute_detailed_cost(
    instance::Instance;
    ds::Vector{Int}=collect(1:(instance.D)),
    cs::Vector{Int}=collect(1:(instance.C)),
    ms::Vector{Int}=collect(1:(instance.M)),
    ts::Vector{Int}=collect(1:(instance.T)),
    solution::Solution=instance.solution,
)
    D, C = instance.D, instance.C
    depots, customers = instance.depots[ds], instance.customers[cs]
    routes = list_routes(solution)
    R = length(routes)

    details = OrderedDict{Symbol,Int}()

    println()

    println("$D depots, $C customers, $R routes")

    depot_inventory_cost = sum(compute_inventory_cost(depot, ms, ts) for depot in depots)
    details[:depot_inventory_cost] = depot_inventory_cost
    println(
        "Cost depots inventory: $depot_inventory_cost thus $(depot_inventory_cost / D) per depot",
    )

    customer_inventory_cost = sum(
        compute_inventory_cost(customer, ms, ts) for customer in customers
    )
    details[:customer_inventory_cost] = customer_inventory_cost
    println(
        "Cost customers inventory: $customer_inventory_cost thus $(customer_inventory_cost / C) per customer",
    )

    customer_shortage_cost = sum(
        compute_shortage_cost(customer, ms, ts) for customer in customers
    )
    details[:customer_shortage_cost] = customer_shortage_cost
    println(
        "Cost customers shortage : $customer_shortage_cost thus $(customer_shortage_cost / C) per customer",
    )

    total_cost = depot_inventory_cost + customer_inventory_cost + customer_shortage_cost

    if length(routes) > 0
        vehicle_costs = sum(get_vehicle_cost(instance) for route in routes)
        details[:vehicle_costs] = vehicle_costs
        println("Cost routes vehicles : $vehicle_costs thus $(vehicle_costs / R) per route")

        stop_costs = sum(compute_stops_cost(route, instance) for route in routes)
        details[:stop_costs] = stop_costs
        println("Cost routes stops : $stop_costs thus $(stop_costs / R) per route")

        km_costs = sum(compute_km_cost(route, instance) for route in routes)
        details[:km_costs] = km_costs
        println("Cost routes kms : $km_costs thus $(km_costs / R) per route")

        total_cost += vehicle_costs + stop_costs + km_costs
    end

    println("Total cost : $total_cost")
    return total_cost, details
end

"""
    compute_cost(instance::Instance;
                    ds::Vector{Int} = collect(1:instance.D),
                    cs::Vector{Int} = collect(1:instance.C),
                    ms::Vector{Int} = collect(1:instance.M),
                    ts::Vector{Int} = collect(1:instance.T),
                    solution::Solution = instance.solution,
                    verbose::Bool = false,
    )

Compute the total cost of the `solution` of `instance`, choose to print detailed results or not.

Two possible cases:
- `verbose` is `true`: we call [`compute_detailed_cost`](@ref).
- `verbose` is `false`: we call [`compute_undetailed_cost`](@ref).
"""
function compute_cost(
    instance::Instance;
    ds::Vector{Int}=collect(1:(instance.D)),
    cs::Vector{Int}=collect(1:(instance.C)),
    ms::Vector{Int}=collect(1:(instance.M)),
    ts::Vector{Int}=collect(1:(instance.T)),
    solution::Solution=instance.solution,
    verbose::Bool=false,
)
    if verbose
        total_cost, _ = compute_detailed_cost(
            instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=solution
        )
        return total_cost
    else
        return compute_undetailed_cost(
            instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=solution
        )
    end
end
