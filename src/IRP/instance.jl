"""
    Instance

An IRP instance gathers all information needed to define the problem.

Commodities, depots, customers, time and transport information is stored here. A solution can also be saved.

# Fields
- `T::Int`: horizon.
- `D::Int`: number of depots.
- `C::Int`: number of customers.
- `M::Int`: number of commodities.

- `vehicle_capacity::Int`: capacity of a vehicle (1D).
- `km_cost::Int`: unit kilometer cost.
- `vehicle_cost::Int`: cost of making a stop for a delivery.
- `stop_cost::Int`: cost for using a vehicle.
- `nb_transport_hours_per_day::Int`: number of transport hours possible in a day.
- `S_max::Int`: maximum number of stops in a route. 

- `commodities::Vector{Commodity}`: the commodities.
- `depots::Vector{Depot}`: the depots.
- `customers::Vector{Customer}`: the customers.
- `dist::Matrix{Int}`: distances between sites in kilometers.
- `transport_durations::Matrix{Int}`: durations between sites in hours.

- `solution::StructuredSolution`: current solution of the instance.
"""
mutable struct Instance
    T::Int
    D::Int
    C::Int
    M::Int

    vehicle_capacity::Int
    km_cost::Int
    vehicle_cost::Int
    stop_cost::Int
    nb_transport_hours_per_day::Int
    S_max::Int

    commodities::Vector{Commodity}
    depots::Vector{Depot}
    customers::Vector{Customer}
    dist::Matrix{Int}
    transport_durations::Matrix{Int}

    solution::StructuredSolution

    function Instance(;
        T,
        D,
        C,
        M,
        vehicle_capacity,
        km_cost,
        vehicle_cost,
        stop_cost,
        nb_transport_hours_per_day,
        S_max,
        commodities,
        depots,
        customers,
        dist,
        transport_durations,
        solution,
    )
        return new(
            T,
            D,
            C,
            M,
            vehicle_capacity,
            km_cost,
            vehicle_cost,
            stop_cost,
            nb_transport_hours_per_day,
            S_max,
            commodities,
            depots,
            customers,
            dist,
            transport_durations,
            StructuredSolution(T, D),
        )
    end
end

## Array version of an instance (deprecated)
mutable struct InstanceArrays
    T::Int
    D::Int
    C::Int
    M::Int

    vehicle_capacity::Int
    km_cost::Int
    vehicle_cost::Int
    stop_cost::Int
    nb_transport_hours_per_day::Int
    S_max::Int
    dist::Matrix{Int}
    transport_durations::Matrix{Int}

    l::Vector{Int}

    excess_inventory_costs_depots::Matrix{Int}
    excess_inventory_costs_customers::Matrix{Int}
    shortage_costs_customers::Matrix{Int}

    initial_inventory_depots::Matrix{Int}
    initial_inventory_customers::Matrix{Int}

    maximum_inventory_depots::Array{Int,3}
    maximum_inventory_customers::Array{Int,3}

    production_depots::Array{Int,3}
    demand_customers::Array{Int,3}

    quantity_sent_depots::Array{Int,3}
    quantity_received_customers::Array{Int,3}

    inventory_depots::Array{Int,3}
    inventory_customers::Array{Int,3}

    solution::StructuredSolution

    function InstanceArrays(instance::Instance)
        D, C, T, M = instance.D, instance.C, instance.T, instance.M
        vehicle_capacity, km_cost, stop_cost, vehicle_cost = instance.vehicle_capacity,
        instance.km_cost,
        instance.stop_cost,
        instance.vehicle_cost
        nb_transport_hours_per_day = instance.nb_transport_hours_per_day
        S_max = instance.S_max
        depots, customers = instance.depots, instance.customers
        dist = instance.dist
        transport_durations = instance.transport_durations

        l = Int[instance.commodities[m].l for m = 1:M]

        excess_inventory_costs_depots =
            [depots[d].excess_inventory_cost[m] for m = 1:M, d = 1:D]
        excess_inventory_costs_customers =
            [customers[c].excess_inventory_cost[m] for m = 1:M, c = 1:C]
        shortage_costs_customers = [customers[c].shortage_cost[m] for m = 1:M, c = 1:C]

        initial_inventory_depots = [depots[d].initial_inventory[m] for m = 1:M, d = 1:D]
        initial_inventory_customers =
            [customers[c].initial_inventory[m] for m = 1:M, c = 1:C]

        maximum_inventory_depots =
            [depots[d].maximum_inventory[m, t] for m = 1:M, d = 1:D, t = 1:T]
        maximum_inventory_customers =
            [customers[c].maximum_inventory[m, t] for m = 1:M, c = 1:C, t = 1:T]

        production_depots = [depots[d].production[m, t] for m = 1:M, d = 1:D, t = 1:T]
        demand_customers = [customers[c].demand[m, t] for m = 1:M, c = 1:C, t = 1:T]

        quantity_sent_depots = [depots[d].quantity_sent[m, t] for m = 1:M, d = 1:D, t = 1:T]
        quantity_received_customers =
            [customers[c].quantity_received[m, t] for m = 1:M, c = 1:C, t = 1:T]

        inventory_depots = [depots[d].inventory[m, t] for m = 1:M, d = 1:D, t = 1:T]
        inventory_customers = [customers[c].inventory[m, t] for m = 1:M, c = 1:C, t = 1:T]

        solution = instance.solution

        return new(
            T,
            D,
            C,
            M,
            vehicle_capacity,
            km_cost,
            vehicle_cost,
            stop_cost,
            nb_transport_hours_per_day,
            S_max,
            dist,
            transport_durations,
            l,
            excess_inventory_costs_depots,
            excess_inventory_costs_customers,
            shortage_costs_customers,
            initial_inventory_depots,
            initial_inventory_customers,
            maximum_inventory_depots,
            maximum_inventory_customers,
            production_depots,
            demand_customers,
            quantity_sent_depots,
            quantity_received_customers,
            inventory_depots,
            inventory_customers,
            solution,
        )
    end
end

"""
    Base.show(io::IO, instance::Instance)

Display `instance` in the terminal.
"""
function Base.show(io::IO, instance::Instance)
    str = "IRP Instance with $(instance.T) days, $(instance.D) depots, $(instance.C) customers, $(instance.M) commodities and $(nb_routes(instance.solution)) routes in the solution."
    print(io, str)
end

"""
    Base.copy(instance::Instance)

Copy `instance`.
"""
function Base.copy(instance::Instance)
    return Instance(
        T = instance.T,
        D = instance.D,
        C = instance.C,
        M = instance.M,
        vehicle_capacity = instance.vehicle_capacity,
        km_cost = instance.km_cost,
        vehicle_cost = instance.vehicle_cost,
        stop_cost = instance.stop_cost,
        nb_transport_hours_per_day = instance.nb_transport_hours_per_day,
        S_max = instance.S_max,
        commodities = [copy(commodity) for commodity in instance.commodities],
        depots = [copy(depot) for depot in instance.depots],
        customers = [copy(customer) for customer in instance.customers],
        dist = copy(instance.dist),
        transport_durations = copy(instance.transport_durations),
        solution = copy(instance.solution),
    )
end

## Getters
"""
    get_vehicle_cost(instance::Instance)

Get the vehicle cost data of `instance`.

It is used in the cost functions as [`compute_route_cost`](@ref).
"""
get_vehicle_cost(instance::Instance) = instance.vehicle_cost


## Customer and depot filters
"""
    select_relevant_depots(instance::Instance, m::Int)

Select the depots having positive initial inventory 
or positive cumulated release over the horizon in commodity `m`.

It is used in the graph creation in [`commodity_flow_graph`](@ref) to sparsify.
"""
function select_relevant_depots(instance::Instance, m::Int)
    depots_concerned = [uses_commodity(depot, m) for depot in instance.depots]
    return depots_concerned
end

"""
    select_relevant_customers(instance::Instance, m::Int)

Select the customers having positive initial inventory 
or positive cumulated demand over the horizon in commodity `m`.

It is used in the graph creation in [`commodity_flow_graph`](@ref) to sparsify.
"""
function select_relevant_customers(instance::Instance, m::Int)
    customers_concerned = [uses_commodity(customer, m) for customer in instance.customers]
    return customers_concerned
end

"""
    commodities_used_depot(instance::Instance, d::Int)

Select the commodities with positive initial inventory 
or positive cumulated release over the horizon at depot `d`.
"""
function commodities_used_depot(instance::Instance, d::Int)
    return commodities_used(instance.depots[d])
end

"""
    commodities_used_customer(instance::Instance, c::Int)

Select the commodities with positive initial inventory 
or positive cumulated demand over the horizon at customer `c`.

It is used in the customer reinsertion large neighborhood.
"""
function commodities_used_customer(instance::Instance, c::Int)
    return commodities_used(instance.customers[c])
end

## Route analysis
"""
    content_size(stop::RouteStop, instance::Instance)

Compute the 1D space occupied by the quantities to be sent to `stop`.
"""
function content_size(stop::RouteStop, instance::Instance)
    leng = 0
    for m = 1:instance.M
        leng += stop.Q[m] * instance.commodities[m].l
    end
    return leng
end

"""
    content_size(route::Route, instance::Instance)

Compute the space used in the 1D vehicle of `route` by all stops deliveries.
"""
function content_size(route::Route, instance::Instance)
    leng = 0
    for stop in route.stops, m = 1:instance.M
        leng += stop.Q[m] * instance.commodities[m].l
    end
    return leng
end

"""
    compute_nb_km(route::Route, instance::Instance)

Compute the number of kilometers travelled along `route`.
"""
function compute_nb_km(route::Route, instance::Instance)
    D = instance.D
    dist = instance.dist
    v1, v2 = 0, 0
    distance = 0
    for (s, stop) in enumerate(route.stops)
        if s == 1
            v1, v2 = route.d, D + stop.c
        else
            v1, v2 = v2, D + stop.c
        end
        distance += dist[v1, v2]
    end
    return distance
end

"""
    compute_route_duration(route::Route, instance::Instance)

Compute the total duration of `route` in hours.
"""
function compute_route_duration(route::Route, instance::Instance)
    D = instance.D
    transport_durations = instance.transport_durations
    v1, v2 = 0, 0
    duration = 0
    for (s, stop) in enumerate(route.stops)
        if s == 1
            v1, v2 = route.d, D + stop.c
        else
            v1, v2 = v2, D + stop.c
        end
        duration += transport_durations[v1, v2]
    end
    return duration
end


"""
    routes_to_sent_quantities(solution::StructuredSolution, instance::Instance)

Deduce the quantities sent from each depot to each customer 
per commodity and per day from `solution` (set of routes).
"""
function routes_to_sent_quantities(solution::StructuredSolution, instance::Instance)
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    sent_quantities = zeros(Int, M, D, C, T)
    for t = 1:T
        for d = 1:D
            for route in solution.routes_per_day_and_depot[t, d]
                for stop in route.stops
                    c = stop.c
                    sent_quantities[:, d, c, t] += stop.Q
                end
            end
        end
    end
    return sent_quantities
end

"""
    routes_to_sent_quantities(solution::SimpleSolution, instance::Instance)

Deduce the quantities sent from each depot to each customer 
per commodity and per day from a simple `solution` (set of routes).
"""
function routes_to_sent_quantities(solution::SimpleSolution, instance::Instance)
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    sent_quantities = zeros(Int, M, D, C, T)
    for route in solution.routes
        t, d = route.t, route.d
        for stop in route.stops
            c = stop.c
            sent_quantities[:, d, c, t] += stop.Q
        end
    end
    return sent_quantities
end

"""
    ratio_demanded_released(instance::Instance)

Estimate the ratio quantity released/quantity demanded per commodity.

We use it as ratio to rescale unbalanced instances 
in [`rescale_release_demand!`](@ref) to test algorithms.
"""
function ratio_demanded_released(instance::Instance)
    total_releases = zeros(instance.M)
    for depot in instance.depots
        total_releases .+= sum(depot.production, dims = 2)[:, 1]
    end
    total_demands = zeros(instance.M)
    for customer in instance.customers
        total_demands .+= sum(customer.demand, dims = 2)[:, 1]
    end
    return total_demands ./ total_releases
end


"""
    rescale_release_demand!(instance::Instance; verbose::Bool = false)

Rescale `instance` demand and release.

The aim is to have total demand close to total release. Instances with 
this property are more difficult to solve. 
"""
function rescale_release_demand!(instance::Instance; verbose::Bool = false)
    ratios = ratio_demanded_released(instance)
    for depot in instance.depots
        for m = 1:instance.M
            if ratios[m] == Inf ||
               isnan(ratios[m]) ||
               any(depot.production[m, :] .> 100000) ||
               any(depot.maximum_inventory[m, :] .> 100000)
                continue
            else
                for t = 1:instance.T
                    depot.production[m, t] = floor(depot.production[m, t] * ratios[m])
                    depot.maximum_inventory[m, t] =
                        floor(depot.maximum_inventory[m, t] * ratios[m])
                end
            end
        end
    end
    verbose && println("Scaled production to meet demand")
end
