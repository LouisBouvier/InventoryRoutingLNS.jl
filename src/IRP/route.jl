"""
    RouteStop

Stop where a delivery is processed. 

# Fields
- `c::Int`: customer where the stop is made.
- `t::Int`: arrival day in the stop.
- `Q::Vector{Int}`: quantities to deliver per commodity.
"""
mutable struct RouteStop
    c::Int
    t::Int
    Q::Vector{Int}

    RouteStop(; c, t, Q) = new(c, t, Q)
end

"""
    Route

A route corresponds to a path and deliveries per customer.

# Fields
- `id::Int`: id of the route.
- `t::Int`: start date.
- `d::Int`: start depot.

- `stops::Vector{RouteStop}`: stops processed by the route.
"""
mutable struct Route
    id::Int
    t::Int
    d::Int

    stops::Vector{RouteStop}

    Route(; t, d, stops) = new(rand(Int), t, d, stops)
end

"""
    Base.show(io::IO, route::Route)

Display `route` in the terminal.
"""
function Base.show(io::IO, route::Route)
    str = "Route on day $(route.t) from depot $(route.d) with stops at customers $([stop.c for stop in route.stops])"
    # for (stoprank, stop) in enumerate(route.stops)
    #     str *= "\n      Stop $stoprank"
    #     str *= "\n      Customer $(stop.c)"
    #     str *= "\n      Delivery $(stop.Q)"
    # end
    print(io, str)
end

"""
    Base.copy(stop::RouteStop)

Copy route `stop`.
"""
function Base.copy(stop::RouteStop)
    return RouteStop(c = stop.c, t = copy(stop.t), Q = stop.Q)
end

"""
    Base.copy(route::Route)

Copy `route`.
"""
function Base.copy(route::Route)
    return Route(t = route.t, d = route.d, stops = copy(route.stops))
end

"""
    mycopy(stop::RouteStop)

Custom copy of a route `stop`.

This is currently used in routing neighborhoods.
"""
function mycopy(stop::RouteStop)
    return RouteStop(c = stop.c, t = stop.t, Q = stop.Q)
end

"""
    mycopy(stops::Vector{RouteStop})

Custom copy of a vector of route stops.

This is currently used in routing neighborhoods.
"""
function mycopy(stops::Vector{RouteStop})
    return [mycopy(stop) for stop in stops]
end

"""
    mycopy(route::Route)

Custom copy of `route`.

This is currently used in routing neighborhoods.
"""
function mycopy(route::Route)
    return Route(t = route.t, d = route.d, stops = [mycopy(stop) for stop in route.stops])
end


## Getters
"""
    get_M(stop::RouteStop)

Get the number of commodities `M` from `stop`.
"""
get_M(stop::RouteStop) = length(stop.Q)

"""
    unique_stops(route::Route)

Get the set of customer indices visited by `route`.
"""
unique_stops(route::Route) = unique(stop.c for stop in route.stops)

"""
    unique_stops(routes::Vector{Route})

Get the set of customer indices visited by the set of `routes`.
"""
function unique_stops(routes::Vector{Route})
    return unique(stop.c for route in routes for stop in route.stops)
end

"""
    get_nb_stops(route::Route)

Get the number of (customer) stops of `route`.
"""
get_nb_stops(route::Route) = length(route.stops)

"""
    get_nb_unique_stops(route::Route)

Get the number of distinct (customer) stops of `route`.
"""
get_nb_unique_stops(route::Route) = length(unique_stops(route))

"""
    uses_commodity(stop::RouteStop, m::Int)

Check if commodity `m` is delivered to `stop`.
"""
uses_commodity(stop::RouteStop, m::Int) = stop.Q[m] > 0

"""
    uses_commodity(route::Route, m::Int)

Check if commodity `m` is delivered to any stop visited by `route`.
"""
function uses_commodity(route::Route, m::Int)
    return any(uses_commodity(stop, m) for stop in route.stops)
end

"""
    check_if_connected(routes1::Vector{Route}, routes2::Vector{Route})

Check if two sets of routes are connected by the sites they involve.

Two sets of routes are connected if they share any site (depot or customer).
"""
function check_if_connected(routes1::Vector{Route}, routes2::Vector{Route})
    depots1 = unique([route.d for route in routes1])
    depots2 = unique([route.d for route in routes2])
    customers1 = Vector{Int}()
    customers2 = Vector{Int}()
    for route in routes1
        append!(customers1, unique_stops(route))
    end
    for route in routes2 
        append!(customers2, unique_stops(route))
    end
    if !isempty(intersect(Set(depots1), Set(depots2))) || !isempty(intersect(Set(customers1), Set(customers2)))
        return true
    else
        return false
    end
end



"""
    decouple_routes(routes::Vector{Route})

Decouple a set of routes into sets of routes 
that do not share any depot or customer.

It can be used to decompose a MILP into smaller ones.
For instance, see [`refill_routes!`](@ref).
"""
function decouple_routes(routes::Vector{Route})
    clusters = collect(1:length(routes))
    old_nb_clusters = length(unique(clusters))
    for i1 in unique(clusters), i2 in unique(clusters)
        if i1 == i2 
            continue
        end
        routes1 = routes[clusters .== i1]
        routes2 = routes[clusters .== i2]
        if check_if_connected(routes1, routes2)
            clusters[clusters .== i2] .= i1
            break 
        end
    end
    nb_clusters = length(unique(clusters))
    while old_nb_clusters != nb_clusters
        old_nb_clusters = nb_clusters
        for i1 in unique(clusters), i2 in unique(clusters)
            if i1 == i2 
                continue
            end
            routes1 = routes[clusters .== i1]
            routes2 = routes[clusters .== i2]
            if check_if_connected(routes1, routes2)
                clusters[clusters .== i2] .= i1 
                break
            end
        end
        nb_clusters = length(unique(clusters))
    end
    return clusters 
end