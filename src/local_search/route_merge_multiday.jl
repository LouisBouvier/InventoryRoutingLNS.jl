"""
    concatenate_multiday(routes::Vector{Route})::Route

Concatenate `routes` that share the same depot, shifting them all to the earliest day.
"""
function concatenate_multiday(routes::Vector{Route})::Route
    t = minimum(route.t for route in routes)
    d = routes[1].d
    for route in routes
        if route.d != d
            error("Routes with different depots")
        end
    end
    return Route(t = t, d = d, stops = [copy(stop) for route in routes for stop in route.stops])
end

function merge_multiday(route1::Route, route2::Route, instance::Instance)
    newroute = concatenate_multiday([copy(route1), copy(route2)])
    update_route_order!(newroute, instance, collect(1:get_nb_stops(newroute)))
    # optimize_route!(newroute, instance)
    compress!(newroute, instance)
    return newroute
end

"""
    gain_merge_multiday(route1::Route, 
                        route2::Route, 
                        instance::Instance
    )::Float64

Compute the cost gain of merging two routes.

`Inf` if infeasible.
"""
function gain_merge_multiday(route1::Route, route2::Route, instance::Instance)::Float64

    if content_size(route1, instance) + content_size(route2, instance) >
       instance.vehicle_capacity
        return Inf
    elseif length(unique_stops([route1, route2])) > instance.S_max
        return Inf
    else
        newroute = merge_multiday(route1, route2, instance)
        if feasibility(newroute, instance)
            # Parameters
            T, M, = instance.T, instance.M
            #  Localize and compute old cost
            cs = unique_stops([route1, route2])
            d = route1.d
            earliest_departure_date = min(route1.t, route2.t)
            ts = collect(earliest_departure_date:T)
            ms = [m for m = 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
            oldcost = compute_cost(instance, ds = [d], cs = cs, ms = ms, ts = ts, solution = SimpleSolution([route1, route2]))
            # Compute new cost
            update_instance_some_routes!(instance, [route1, route2], "delete", false)
            update_instance_some_routes!(instance, [newroute], "add", false)
            newcost = compute_cost(instance, ds = [d], cs = cs, ms = ms, ts = ts, solution = SimpleSolution([newroute]))
            feasible =
                feasibility(instance, ds = [d], cs = cs, solution = SimpleSolution([]))
            update_instance_some_routes!(instance, [newroute], "delete", false)
            update_instance_some_routes!(instance, [route1, route2], "add", false)
            if feasible
                return newcost - oldcost
            else
                return Inf
            end
        else
            return Inf
        end
    end
end

"""
    find_best_merge_multiday(instance::Instance, 
                                d::Int
    )

Find the best pair of routes (related to the same depot `d`) to merge based on cost gain.
"""
function find_best_merge_multiday(instance::Instance, d::Int)
    routes = [route for route in list_routes_depot(instance.solution, d)]
    R = length(routes)
    Δ = fill(Inf, R, R)
    for r1 = 1:R, r2 = 1:r1-1
        route1, route2 = routes[r1], routes[r2]
        Δ[r1, r2] = gain_merge_multiday(route1, route2, instance)
    end
    if prod(size(Δ)) > 0
        r1, r2 = Tuple(argmin(Δ))
        route1, route2 = routes[r1], routes[r2]
        return Δ[r1, r2], route1, route2
    else
        return Inf, nothing, nothing
    end
end

"""
    perform_best_merge_multiday!(instance::Instance,
                                    d::Int;
                                    stats::Dict = nothing,
                                    in_LNS::Bool = true,
    )

Perform the best merge over the routes related to the same depot `d`.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function perform_best_merge_multiday!(
    instance::Instance,
    d::Int;
    stats::Dict = nothing,
    in_LNS::Bool = true,
)
    Δ, route1, route2 = find_best_merge_multiday(instance, d)
    if Δ < -0.5
        newroute = merge_multiday(route1, route2, instance)
        update_instance_some_routes!(instance, [route1, route2], "delete")
        update_instance_some_routes!(instance, [newroute], "add")
        if in_LNS
            stats["gain_merge_multiday"] += Δ
        end
        return true
    else
        return false
    end
end

"""
    iterative_merge_multiday!(instance::Instance,
                                d::Int;
                                stats::Dict = nothing,
                                in_LNS::Bool = true,
    )

Apply [`perform_best_merge_multiday!`](@ref) on depot `d` until no improvement found.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_merge_multiday!(
    instance::Instance,
    d::Int;
    stats::Dict = nothing,
    in_LNS::Bool = true,
)
    while true
        improvement_found =
            perform_best_merge_multiday!(instance, d, stats = stats, in_LNS = in_LNS)
        if !improvement_found
            break
        end
    end
end

"""
    iterative_merge_multiday!(instance::Instance,
                                verbose::Bool = false;
                                stats::Dict = nothing,
                                in_LNS::Bool = true,
    )

Apply [`perform_best_merge_multiday!`](@ref) on every depot until no improvement found.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_merge_multiday!(
    instance::Instance,
    verbose::Bool = false;
    stats::Dict = nothing,
    in_LNS::Bool = true,
)
    @showprogress "Greedy merge of routes over days " for d = 1:instance.D
        iterative_merge_multiday!(instance, d, stats = stats, in_LNS = in_LNS)
    end
    verbose && println("Cost after multiday merge : ", compute_cost(instance))
end
