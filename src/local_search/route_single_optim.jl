"""
    update_route_order!(route::Route, instance::Instance, perm::Vector{Int})

Update a `route` from a permutation `perm` of its stops.
"""
function update_route_order!(route::Route, instance::Instance, perm::Vector{Int})
    D = instance.D
    d = route.d 
    t = route.t 
    transport_durations = instance.transport_durations
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    # Change the stops order according to the permutation
    route.stops = route.stops[perm]
    # Update the dates of arrival
    c1 = route.stops[1].c
    cumulated_duration = transport_durations[d, D + c1]
    route.stops[1].t = t + floor(cumulated_duration / nb_transport_hours_per_day)
    for s = 1:get_nb_stops(route)-1
        c1, c2 = route.stops[s].c, route.stops[s+1].c
        cumulated_duration += transport_durations[D + c1, D + c2]
        route.stops[s+1].t = t + floor(cumulated_duration / nb_transport_hours_per_day)
    end
end

"""
    compress!(route::Route, instance::Instance)

Merge stops that visit the same customer, all gathered at the first date of stop.
"""
function compress!(route::Route, instance::Instance)
    if length(route.stops) <= 1
        return
    end
    cs = unique_stops([route])
    if length(cs) < length(route.stops)
        route.stops = [
            RouteStop(c = c, t = min([stop.t for stop in route.stops if stop.c == c]...), Q = sum(stop.Q for stop in route.stops if stop.c == c)) for
            c in cs
        ]
        update_route_order!(route, instance, collect(1:get_nb_stops(route)))
    end
end

"""
    reorder_optimally!(route::Route, instance::Instance)

Find optimal stops' order and apply it to `route`.

Brutal enumeration of the possible permutations.
"""
function reorder_optimally!(route::Route, instance::Instance)
    if length(route.stops) <= 1
        return
    end
    # parameters 
    S = length(route.stops)
    M, T = instance.M, instance.T    
    # Consider affected variables
    departure_time = route.t 
    cs = unique_stops(route)
    ms = [m for m = 1:M if uses_commodity(route, m)]
    ts = collect(departure_time:T)
    # Compute current local cost
    mincost = departure_time + floor(compute_route_duration(route, instance)/instance.nb_transport_hours_per_day) > T ? Inf : compute_cost(instance, ds = Vector{Int}(), cs = cs, ms = ms, ts = ts, solution = SimpleSolution([route]))
    bestorder = collect(1:S)
    # Enumerate permutations (S is small !)
    permutations = collect(Combinatorics.nthperm(1:S, k) for k = 1:factorial(S))
    for permutation in permutations
        route_modified = copy(route)
        update_route_order!(route_modified, instance, permutation)
        if feasibility(route_modified, instance)
            update_instance_some_routes!(instance, [route], "delete", false)
            update_instance_some_routes!(instance, [route_modified], "add", false)
            newcost = compute_cost(instance, ds = Vector{Int}(), cs = cs, ms = ms, ts = ts, solution = SimpleSolution([route_modified]))
            update_instance_some_routes!(instance, [route_modified], "delete", false)
            update_instance_some_routes!(instance, [route], "add", false)
        else
            newcost = Inf
        end
        if newcost < mincost
            mincost = newcost
            bestorder .= permutation
        end
    end
    # Apply it
    update_route_order!(route, instance, bestorder)
    return nothing
end

"""
    optimize_route!(route::Route, instance::Instance)

Compress and reorder `route` to optimality.
"""
function optimize_route!(route::Route, instance::Instance)
    compress!(route, instance)
    # @assert length(route.stops) <= 4
    reorder_optimally!(route, instance)
end

"""
    optimize_route(route::Route, instance::Instance)

Compress and reorder a copy of `route` to optimality.
"""
function optimize_route(route::Route, instance::Instance)
    routecopy = copy(route)
    optimize_route!(routecopy, instance)
    return routecopy
end

"""
    compute_optimized_route_cost(route::Route, instance::Instance)

Compute the cost of an optimally compressed and reordered copy of `route`.
"""
function compute_optimized_route_cost(route::Route, instance::Instance)
    optimized_route = optimize_route(route, instance)
    return compute_route_cost(optimized_route, instance)
end
