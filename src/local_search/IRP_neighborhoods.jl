## Neighborhoods from Silva et al. 2014
"""
    insert_multi_depot!(instance::Instance,
                        route1::Route,
                        route2::Route,
                        i::Int;
                        stats::Dict = nothing,
    )

Push `route1.stops[i]` to `route2.stops` and apply [`compress!`](@ref) to avoid stop repetition.

Only applied on routes with same dates of departure.
"""
function insert_multi_depot!(
    instance::Instance, route1::Route, route2::Route, i::Int; stats::Dict=nothing
)
    route_mod1, route_mod2 = mycopy(route1), mycopy(route2)
    push!(route_mod2.stops, route_mod1.stops[i])
    deleteat!(route_mod1.stops, i)
    if get_nb_unique_stops(route_mod2) > instance.S_max ||
        stop_depot_not_compatible(instance.depots[route2.d], route1.stops[i]) ||
        (content_size(route_mod2, instance) > instance.vehicle_capacity)
        stats["insert_multi_depot_aborted"] += 1
        return false
    end

    if !isempty(route_mod1.stops)
        update_route_order!(route_mod2, instance, collect(1:get_nb_stops(route_mod2)))
        # optimize_route!(route_mod2, instance)
        compress!(route_mod2, instance)

        if route_mod2.stops[end].t > instance.T
            stats["insert_multi_depot_aborted"] += 1
            return false
        end

        update_route_order!(route_mod1, instance, collect(1:get_nb_stops(route_mod1)))
        # optimize_route!(route_mod1, instance)
        compress!(route_mod1, instance)
        # Parameters
        T, M = instance.T, instance.M
        ts = collect((route1.t):T)
        ds = unique(route.d for route in [route1, route2])
        cs = unique([stop.c for stop in route1.stops[i:end]])#unique_stops([route_mod1, route_mod2])
        ms = [m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
        oldcost = compute_cost(
            instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route1, route2])
        )
        update_instance_some_routes!(instance, [route1, route2], "delete", false)
        update_instance_some_routes!(instance, [route_mod1, route_mod2], "add", false)
        if feasibility(
            instance; ds=[route2.d], cs=Vector{Int}(), solution=SimpleSolution([route_mod2])
        )
            newcost = compute_cost(
                instance;
                ds=ds,
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route_mod1, route_mod2]),
            )

        else
            newcost = Inf
        end
        update_instance_some_routes!(instance, [route_mod1, route_mod2], "delete", false)
        update_instance_some_routes!(instance, [route1, route2], "add", false)
        if newcost < oldcost
            update_instance_some_routes!(instance, [route1, route2], "delete")
            update_instance_some_routes!(instance, [route_mod1, route_mod2], "add")
            stats["insert_multi_depot_applied"] += 1
            stats["gain_insert_multi_depot"] += newcost - oldcost
            return true
        else
            stats["insert_multi_depot_aborted"] += 1
            return false
        end
    else
        update_route_order!(route_mod2, instance, collect(1:get_nb_stops(route_mod2)))
        # optimize_route!(route_mod2, instance)
        compress!(route_mod2, instance)

        if route_mod2.stops[end].t > instance.T
            stats["insert_multi_depot_aborted"] += 1
            return false
        end

        # Parameters
        T, M = instance.T, instance.M
        ts = collect((route1.t):T)
        ds = unique(route.d for route in [route1, route2])
        cs = unique([stop.c for stop in route1.stops[i:end]])#unique_stops(route_mod2)
        ms = [m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
        oldcost = compute_cost(
            instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route1, route2])
        )
        update_instance_some_routes!(instance, [route1, route2], "delete", false)
        update_instance_some_routes!(instance, [route_mod2], "add", false)
        if feasibility(
            instance; ds=[route2.d], cs=Vector{Int}(), solution=SimpleSolution([route_mod2])
        )
            newcost = compute_cost(
                instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route_mod2])
            )

        else
            newcost = Inf
        end
        update_instance_some_routes!(instance, [route_mod2], "delete", false)
        update_instance_some_routes!(instance, [route1, route2], "add", false)
        if newcost < oldcost
            update_instance_some_routes!(instance, [route1, route2], "delete")
            update_instance_some_routes!(instance, [route_mod2], "add")
            stats["insert_multi_depot_applied"] += 1
            stats["gain_insert_multi_depot"] += newcost - oldcost
            return true
        else
            stats["insert_multi_depot_aborted"] += 1
            return false
        end
    end
end

"""
    swap_multi_depot!(instance::Instance,
                        route1::Route,
                        route2::Route,
                        i::Int,
                        j::Int;
                        stats::Dict = nothing,
    )

Exchange `route1.stops[i]` and `route2.stops[j]` and apply [`compress!`](@ref) to avoid stop repetition.

Only applied on routes with same dates of departure.
"""
function swap_multi_depot!(
    instance::Instance, route1::Route, route2::Route, i::Int, j::Int; stats::Dict=nothing
)
    if stop_depot_not_compatible(instance.depots[route2.d], route1.stops[i])
        stats["swap_multi_depot_aborted"] += 1
        return false
    end

    if stop_depot_not_compatible(instance.depots[route1.d], route2.stops[j])
        stats["swap_multi_depot_aborted"] += 1
        return false
    end

    route_mod1, route_mod2 = mycopy(route1), mycopy(route2)

    stop1 = mycopy(route1.stops[i])
    stop2 = mycopy(route2.stops[j])

    route_mod1.stops[i] = stop2
    route_mod2.stops[j] = stop1

    if content_size(route_mod1, instance) > instance.vehicle_capacity ||
        content_size(route_mod2, instance) > instance.vehicle_capacity
        stats["swap_multi_depot_aborted"] += 1
        return false
    end

    update_route_order!(route_mod1, instance, collect(1:get_nb_stops(route_mod1)))
    update_route_order!(route_mod2, instance, collect(1:get_nb_stops(route_mod2)))
    # optimize_route!(route_mod1, instance)
    # optimize_route!(route_mod2, instance)
    compress!(route_mod1, instance)
    compress!(route_mod2, instance)

    if route_mod2.stops[end].t > instance.T || route_mod1.stops[end].t > instance.T
        stats["swap_multi_depot_aborted"] += 1
        return false
    end

    # Parameters
    T, M = instance.T, instance.M
    ts = collect((route1.t):T)
    ds = unique(route.d for route in [route1, route2])
    cs = unique(
        vcat(
            [stop.c for stop in route1.stops[i:end]],
            [stop.c for stop in route2.stops[j:end]],
        ),
    ) #unique_stops([route1, route2])
    ms = [m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
    # Compute old cost
    oldcost = compute_cost(
        instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route1, route2])
    )
    update_instance_some_routes!(instance, [route1, route2], "delete", false)
    update_instance_some_routes!(instance, [route_mod1, route_mod2], "add", false)
    if feasibility(
        instance; ds=ds, cs=Vector{Int}(), solution=SimpleSolution([route_mod1, route_mod2])
    )
        newcost = compute_cost(
            instance;
            ds=ds,
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([route_mod1, route_mod2]),
        )

    else
        newcost = Inf
    end
    update_instance_some_routes!(instance, [route_mod1, route_mod2], "delete", false)
    update_instance_some_routes!(instance, [route1, route2], "add", false)
    if newcost < oldcost
        update_instance_some_routes!(instance, [route1, route2], "delete")
        update_instance_some_routes!(instance, [route_mod1, route_mod2], "add")
        stats["swap_multi_depot_applied"] += 1
        stats["gain_swap_multi_depot"] += newcost - oldcost
        return true
    else
        stats["swap_multi_depot_aborted"] += 1
        return false
    end
end

"""
    iterative_insert_multi_depot!(instance::Instance, 
                                    t::Int; 
                                    stats::Dict = nothing
    )

Try [`insert_multi_depot!`](@ref) on pairs of routes sampled on day `t`.
"""
function iterative_insert_multi_depot!(instance::Instance, t::Int; stats::Dict=nothing)
    R = nb_routes(instance.solution, t)
    nb_it = floor(R^2 * 0.3) # subsample the number of pairs considered
    for it in 1:nb_it
        R = nb_routes(instance.solution, t)
        r1 = Random.rand(1:R)
        r2 = Random.rand(1:R)
        if r1 == r2
            continue
        end
        route1 = get_route_day(instance.solution, t, r1)
        route2 = get_route_day(instance.solution, t, r2)
        for i in 1:length(route1.stops)
            improvement_achieved = insert_multi_depot!(
                instance, route1, route2, i; stats=stats
            )
            if improvement_achieved
                break
            end
        end
    end
end

"""
    iterative_swap_multi_depot!(instance::Instance, 
                                t::Int; 
                                stats::Dict = nothing
    )

Try [`swap_multi_depot!`](@ref) on pairs of routes sampled on day `t`.
"""
function iterative_swap_multi_depot!(instance::Instance, t::Int; stats::Dict=nothing)
    R = nb_routes(instance.solution, t)
    nb_it = floor(R^2 * 0.3) # subsample the number of pairs considered
    for it in 1:nb_it
        R = nb_routes(instance.solution, t)
        r1 = Random.rand(1:R)
        r2 = Random.rand(1:R)
        if r1 == r2
            continue
        end
        route1 = get_route_day(instance.solution, t, r1)
        route2 = get_route_day(instance.solution, t, r2)
        for i in 1:length(route1.stops), k in 1:length(route2.stops)
            improvement_achieved = swap_multi_depot!(
                instance, route1, route2, i, k; stats=stats
            )
            if improvement_achieved
                break
            end
        end
    end
end

"""
    insert_swap_multi_depot_per_day!(instance::Instance; 
                                        stats::Dict = nothing
    )

Apply [`iterative_insert_multi_depot!`](@ref) and [`iterative_swap_multi_depot!`](@ref) every day.
"""
function insert_swap_multi_depot_per_day!(instance::Instance; stats::Dict=nothing)
    T = instance.T
    @showprogress "Insert and swap per day: " for t in 1:T
        iterative_insert_multi_depot!(instance, t; stats=stats)
        iterative_swap_multi_depot!(instance, t; stats=stats)
    end
end

"""
    two_opt_star_multi_depot!(instance::Instance,
                                route1::Route,
                                route2::Route,
                                k::Int,
                                l::Int;
                                stats::Dict = nothing,
    )

Exchange `route1.stops[k+1:end]` with `route2.stops[l+1:end]` and compress.

Only applied on routes with same dates of departure.
"""
function two_opt_star_multi_depot!(
    instance::Instance, route1::Route, route2::Route, k::Int, l::Int; stats::Dict=nothing
)
    newroute1, newroute2 = mycopy(route1), mycopy(route2)
    newroute1_begin, newroute1_end = mycopy(route1.stops[1:k]),
    mycopy(route2.stops[(l + 1):end])
    newroute2_begin, newroute2_end = mycopy(route2.stops[1:l]),
    mycopy(route1.stops[(k + 1):end])
    newroute1.stops = vcat(newroute1_begin, newroute1_end)
    newroute2.stops = vcat(newroute2_begin, newroute2_end)

    if get_nb_unique_stops(newroute1) > instance.S_max ||
        get_nb_unique_stops(newroute2) > instance.S_max
        stats["two_opt_star_multi_depot_aborted"] += 1
        return false
    end

    if content_size(newroute1, instance) > instance.vehicle_capacity ||
        content_size(newroute2, instance) > instance.vehicle_capacity
        stats["two_opt_star_multi_depot_aborted"] += 1
        return false
    end

    for stop in route2.stops[(l + 1):end]
        if stop_depot_not_compatible(instance.depots[route1.d], stop)
            stats["two_opt_star_multi_depot_aborted"] += 1
            return false
        end
    end

    for stop in route1.stops[(k + 1):end]
        if stop_depot_not_compatible(instance.depots[route2.d], stop)
            stats["two_opt_star_multi_depot_aborted"] += 1
            return false
        end
    end

    update_route_order!(newroute1, instance, collect(1:get_nb_stops(newroute1)))
    update_route_order!(newroute2, instance, collect(1:get_nb_stops(newroute2)))
    # optimize_route!(newroute1, instance)
    # optimize_route!(newroute2, instance)
    compress!(newroute1, instance)
    compress!(newroute2, instance)

    if newroute1.stops[end].t > instance.T || newroute2.stops[end].t > instance.T
        stats["two_opt_star_multi_depot_aborted"] += 1
        return false
    end

    # Parameters
    T, M = instance.T, instance.M
    ts = collect((route1.t):T)
    ds = unique(route.d for route in [route1, route2])
    cs = unique(
        vcat(
            [stop.c for stop in route1.stops[(k + 1):end]],
            [stop.c for stop in route2.stops[(l + 1):end]],
        ),
    )
    ms = [m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
    # Compute old cost
    oldcost = compute_cost(
        instance; ds=ds, cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route1, route2])
    )
    update_instance_some_routes!(instance, [route1, route2], "delete", false)
    update_instance_some_routes!(instance, [newroute1, newroute2], "add", false)
    if feasibility(
        instance; ds=ds, cs=Vector{Int}(), solution=SimpleSolution([newroute1, newroute2])
    )
        newcost = compute_cost(
            instance;
            ds=ds,
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([newroute1, newroute2]),
        )
    else
        newcost = Inf
    end
    update_instance_some_routes!(instance, [newroute1, newroute2], "delete", false)
    update_instance_some_routes!(instance, [route1, route2], "add", false)
    if newcost >= oldcost
        stats["two_opt_star_multi_depot_aborted"] += 1
        return false
    else
        update_instance_some_routes!(instance, [route1, route2], "delete")
        update_instance_some_routes!(instance, [newroute1, newroute2], "add")
        stats["two_opt_star_multi_depot_applied"] += 1
        stats["gain_two_opt_star_multi_depot"] += newcost - oldcost
        return true
    end
end

"""
    iterative_two_opt_star_multi_depot!(instance::Instance, 
                                        t::Int; 
                                        stats::Dict = nothing
    )

Try [`two_opt_star_multi_depot!`](@ref) on pairs of routes sampled on day `t`.
"""
function iterative_two_opt_star_multi_depot!(
    instance::Instance, t::Int; stats::Dict=nothing
)
    R = nb_routes(instance.solution, t)
    for r1 in 1:R, r2 in 1:R
        if r1 == r2 || Random.rand(Float64, 1)[1] < 0.90
            continue
        end
        route1 = get_route_day(instance.solution, t, r1)
        route2 = get_route_day(instance.solution, t, r2)
        for k in 1:(length(route1.stops) - 1), l in 1:(length(route2.stops) - 1)
            improvement_achieved = two_opt_star_multi_depot!(
                instance, route1, route2, k, l; stats=stats
            )
            if improvement_achieved
                break
            end
        end
    end
end

"""
    two_opt_star_multi_depot_per_day!(instance::Instance; 
                                        stats::Dict = nothing
    )

Apply [`iterative_two_opt_star_multi_depot!`](@ref) every day.
"""
function two_opt_star_multi_depot_per_day!(instance::Instance; stats::Dict=nothing)
    T = instance.T
    @showprogress "Two_opt_star_multi_depot per day: " for t in 1:(instance.T)
        iterative_two_opt_star_multi_depot!(instance, t; stats=stats)
    end
end
