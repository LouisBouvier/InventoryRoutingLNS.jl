## Feasibility route
"""
    delays_coherent(route::Route, instance::Instance; verbose::Bool = false)

Check if the dates of the deliveries of `route` are coherent with transport durations.

In the [`Instance`](@ref) structure, we have a maximum number of transport hours 
per day `nb_transport_hours_per_day`, as well as the transport duration for each 
site-to-site travel in `transport_durations`. We can therefore follow the path of 
`route` and check if the dates and transport durations are coherent. 
"""
function delays_coherent(route::Route, instance::Instance; verbose::Bool=false)
    transport_durations = instance.transport_durations
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    D = instance.D
    depot_index = route.d
    nb_stops_route = get_nb_stops(route)
    customer_index = route.stops[1].c + D
    cumulated_duration = transport_durations[depot_index, customer_index]
    if route.t + floor(cumulated_duration / nb_transport_hours_per_day) != route.stops[1].t
        verbose &&
            @info "Route $(route.id) has arrival time incoherent with delays for stop 1"
        return false
    end
    for s in 1:(nb_stops_route - 1)
        customer1_index = route.stops[s].c + D
        customer2_index = route.stops[s + 1].c + D
        cumulated_duration += transport_durations[customer1_index, customer2_index]
        if route.t + floor(cumulated_duration / nb_transport_hours_per_day) !=
            route.stops[s + 1].t
            verbose &&
                @info "Route $(route.id) has arrival time incoherent with delays for stop $(s+1)"
            return false
        end
    end
    return true
end

"""
    feasibility(route::Route, instance::Instance; verbose::Bool = false)

Check if `route` is feasible for `instance`.

A route is feasible if each of the following conditions is respected:
- the number of stops does not exceed `S_max`.
- the total content size of the deliveries is below the vehicle capacity.
- the arrival date to the last stop is before the horizon `T`.
- the dates of arrival in the stops are coherent with transport durations.
"""
function feasibility(route::Route, instance::Instance; verbose::Bool=false)
    if !(1 <= length(route.stops) <= instance.S_max)
        verbose && @info "Route $(route.id) is too long"
        return false
    elseif content_size(route, instance) > instance.vehicle_capacity
        verbose && @info "Route $(route.id) has too much content"
        return false
    elseif route.t + floor(
        compute_route_duration(route, instance) / instance.nb_transport_hours_per_day
    ) > instance.T
        verbose && @info "Route $(route.id) arrives after the horizon"
        return false
    elseif !delays_coherent(route, instance; verbose=verbose)
        return false
    else
        return true
    end
end

## Feasibility depots

"""
    feasibility(depot::Depot; verbose::Bool = false)

Check if the current solution of `instance` is feasible with respect to `depot` inventory.

Before applying this check, the `instance` and stored `solution` must be coherent.
This can be made manually, or using [`update_instance_from_solution!`](@ref).
We then check if the depot inventory is nonnegative on each day for each commodity.
"""
function feasibility(depot::Depot; verbose::Bool=false)
    if !positive_inventory(depot)
        verbose && @info "Depot $(depot.d) has negative inventory"
        return false
    else
        return true
    end
end

"""
    stop_depot_not_compatible(depot::Depot, stop::RouteStop; verbose::Bool = false)

Check if `stop` contains commodities not used by `depot` (no release or initial inventory).

This check is implicitly done by [`feasibility`](@ref) but faster to compute, we therefore 
do not include it in the feasibility function of a depot, but instead call it when the whole 
feasibility check is not necessary, see [`insert_multi_depot!`](@ref) for instance. 
"""
function stop_depot_not_compatible(depot::Depot, stop::RouteStop; verbose::Bool=false)
    return any((stop.Q .> 0) .* .!(depot.commodity_used))
end

## Feasibility customers

"""
    feasibility(customer::Customer; verbose::Bool = false)

Check if the current solution of `instance` is feasible with respect to `customer` inventory.

Two conditions have to be verified:
- the inventory is nonnegative for each commodity on each day.
- the commodities received are restricted to those demanded.

Remark: the second condition is necessary to avoid sending commdodities 
to customers that do not need them to lower the excess inventory costs at the depots. 
"""
function feasibility(customer::Customer; verbose::Bool=false)
    if !positive_inventory(customer)
        verbose && @info "Customer $(customer.c) has negative inventory"
        return false
    elseif positive_inventory_zero_demand_and_initial_inventory(customer)
        verbose && @info "Customer $(customer.c) has commodities they didn't ask for"
        return false
    else
        return true
    end
end

## Global feasibility

"""
    feasibility(instance::Instance;
                ds::Vector{Int} = collect(1:instance.D),
                cs::Vector{Int} = collect(1:instance.C),
                solution::Solution = instance.solution,
                verbose::Bool = false,
    )

Check if `solution` is feasible for `instance`.

For this function to make sense, we need a coherence between the inventories 
of the sites in `instance` and `solution`. It can be applied to the whole instance 
updated with [`update_instance_from_solution!`](@ref).
It can also be applied locally to a sub-solution corresponding to 
some routes and sub-sets of depots `ds` and customers `cs`, with inventories 
updated using [`update_instance_some_routes!`](@ref).
"""
function feasibility(
    instance::Instance;
    ds::Vector{Int}=collect(1:(instance.D)),
    cs::Vector{Int}=collect(1:(instance.C)),
    solution::Solution=instance.solution,
    verbose::Bool=false,
)
    for route in list_routes(solution)
        if !feasibility(route, instance; verbose=verbose)
            return false
        end
    end
    for depot in instance.depots[ds]
        if !feasibility(depot; verbose=verbose)
            return false
        end
    end
    for customer in instance.customers[cs]
        if !feasibility(customer; verbose=verbose)
            return false
        end
    end
    return true
end
