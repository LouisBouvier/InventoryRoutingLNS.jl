"""
    insert_single_depot!(route1::Route,
                            route2::Route,
                            i::Int,
                            instance::Instance;
                            stats::Dict = nothing,
                            in_LNS::Bool = true,
    )

Push `route1.stops[i]` to `route2.stops` and apply [`compress!`](@ref) to avoid stop repetition.

Only applied on routes with same dates of departure and same starting depot.
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function insert_single_depot!(
    route1::Route,
    route2::Route,
    i::Int,
    instance::Instance;
    stats::Dict=nothing,
    in_LNS::Bool=true,
)
    # Update the routes 
    route2_future_stops = unique(
        vcat([stop.c for stop in route2.stops], [route1.stops[i].c])
    )
    if (
        content_size(route2, instance) + content_size(route1.stops[i], instance) >
        instance.vehicle_capacity
    ) || length(route2_future_stops) > instance.S_max
        if in_LNS
            stats["insert_single_depot_aborted"] += 1
        end
        return false
    end
    route1_mod, route2_mod = mycopy(route1), mycopy(route2)
    push!(route2_mod.stops, route1_mod.stops[i])
    deleteat!(route1_mod.stops, i)
    # Two cases: route1 has still a stop or not
    if get_nb_stops(route1) > 1
        update_route_order!(route1_mod, instance, collect(1:get_nb_stops(route1_mod)))
        # optimize_route!(route1_mod, instance)# Best order has to be checked in case it fosters feasibility
        compress!(route1_mod, instance)
        update_route_order!(route2_mod, instance, collect(1:get_nb_stops(route2_mod)))
        # optimize_route!(route2_mod, instance)
        compress!(route2_mod, instance)
        # initialize old cost 
        oldcost = 1
        if floor(
            compute_route_duration(route2_mod, instance) /
            instance.nb_transport_hours_per_day,
        ) + route2_mod.t <= instance.T
            # Parameters
            M, T = instance.M, instance.T
            # Localize and compute old cost
            cs = unique([stop.c for stop in route1.stops[i:end]]) #unique_stops([route1, route2])
            departure_date = route1.t
            ts = collect(departure_date:T)
            ms = [
                m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))
            ]
            oldcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route1, route2]),
            )
            # Compute new cost
            update_instance_some_routes!(instance, [route1, route2], "delete", false)
            update_instance_some_routes!(instance, [route1_mod, route2_mod], "add", false)
            newcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route1_mod, route2_mod]),
            )
            update_instance_some_routes!(
                instance, [route1_mod, route2_mod], "delete", false
            )
            update_instance_some_routes!(instance, [route1, route2], "add", false)
        else
            newcost = Inf
        end

        if newcost < oldcost
            update_instance_some_routes!(instance, [route1, route2], "delete")
            update_instance_some_routes!(instance, [route1_mod, route2_mod], "add")
            if in_LNS
                stats["gain_insert_single_depot"] += newcost - oldcost
                stats["insert_single_depot_applied"] += 1
            end
            return true
        else
            if in_LNS
                stats["insert_single_depot_aborted"] += 1
            end
            return false
        end
    else
        update_route_order!(route2_mod, instance, collect(1:get_nb_stops(route2_mod)))
        # optimize_route!(route2_mod, instance)
        compress!(route2_mod, instance)
        # initialize old cost 
        oldcost = 1
        if floor(
            compute_route_duration(route2_mod, instance) /
            instance.nb_transport_hours_per_day,
        ) + route2_mod.t <= instance.T
            # Parameters
            M, T = instance.M, instance.T
            # Localize and compute old cost
            cs = unique([stop.c for stop in route1.stops[i:end]]) #unique_stops([route1, route2])
            departure_date = route1.t
            ts = collect(departure_date:T)
            ms = [
                m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))
            ]
            oldcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route1, route2]),
            )
            # Compute new cost
            update_instance_some_routes!(instance, [route1, route2], "delete", false)
            update_instance_some_routes!(instance, [route2_mod], "add", false)
            newcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route2_mod]),
            )
            update_instance_some_routes!(instance, [route2_mod], "delete", false)
            update_instance_some_routes!(instance, [route1, route2], "add", false)
        else
            newcost = Inf
        end

        if newcost < oldcost
            update_instance_some_routes!(instance, [route1, route2], "delete")
            update_instance_some_routes!(instance, [route2_mod], "add")
            if in_LNS
                stats["gain_insert_single_depot"] += newcost - oldcost
                stats["insert_single_depot_applied"] += 1
            end
            return true
        else
            if in_LNS
                stats["insert_single_depot_aborted"] += 1
            end
            return false
        end
    end
end

"""
    swap_single_depot!(route1::Route,
                        route2::Route,
                        i::Int,
                        j::Int,
                        instance::Instance;
                        stats::Dict = nothing,
                        in_LNS::Bool = true,
    )

Exchange `route1.stops[i]` and `route2.stops[j]` and apply [`compress!`](@ref) to avoid stop repetition.

Only applied on routes with same dates of departure and same starting depot.
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function swap_single_depot!(
    route1::Route,
    route2::Route,
    i::Int,
    j::Int,
    instance::Instance;
    stats::Dict=nothing,
    in_LNS::Bool=true,
)
    # Update the routes
    route1_mod, route2_mod = mycopy(route1), mycopy(route2)
    stop1 = mycopy(route1_mod.stops[i])
    stop2 = mycopy(route2_mod.stops[j])
    route1_mod.stops[i] = stop2
    route2_mod.stops[j] = stop1
    if content_size(route1_mod, instance) > instance.vehicle_capacity ||
        content_size(route2_mod, instance) > instance.vehicle_capacity
        if in_LNS
            stats["swap_single_depot_aborted"] += 1
        end
        return false
    end
    update_route_order!(route1_mod, instance, collect(1:get_nb_stops(route1_mod)))
    update_route_order!(route2_mod, instance, collect(1:get_nb_stops(route2_mod)))
    # optimize_route!(route1_mod, instance)
    # optimize_route!(route2_mod, instance)
    compress!(route1_mod, instance)
    compress!(route2_mod, instance)
    # initialize old cost 
    oldcost = 1
    if (
        floor(
            compute_route_duration(route2_mod, instance) /
            instance.nb_transport_hours_per_day,
        ) + route2_mod.t <= instance.T
    ) && (
        floor(
            compute_route_duration(route1_mod, instance) /
            instance.nb_transport_hours_per_day,
        ) + route1_mod.t <= instance.T
    )
        # Parameters
        M, T = instance.M, instance.T
        # Localize and compute old cost
        cs = unique(
            vcat(
                [stop.c for stop in route1.stops[i:end]],
                [stop.c for stop in route2.stops[j:end]],
            ),
        ) #unique_stops([route1, route2])
        departure_date = route1.t
        ts = collect(departure_date:T)
        ms = [
            m for
            m in 1:M if (uses_commodity(route1_mod, m) || uses_commodity(route2_mod, m))
        ]
        oldcost = compute_cost(
            instance;
            ds=Vector{Int}(),
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([route1, route2]),
        )
        # Compute new cost
        update_instance_some_routes!(instance, [route1, route2], "delete", false)
        update_instance_some_routes!(instance, [route1_mod, route2_mod], "add", false)
        newcost = compute_cost(
            instance;
            ds=Vector{Int}(),
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([route1_mod, route2_mod]),
        )
        update_instance_some_routes!(instance, [route1_mod, route2_mod], "delete", false)
        update_instance_some_routes!(instance, [route1, route2], "add", false)
    else
        newcost = Inf
    end

    if newcost < oldcost
        update_instance_some_routes!(instance, [route1, route2], "delete")
        update_instance_some_routes!(instance, [route1_mod, route2_mod], "add")
        if in_LNS
            stats["gain_swap_single_depot"] += newcost - oldcost
            stats["swap_single_depot_applied"] += 1
        end
        return true
    else
        if in_LNS
            stats["swap_single_depot_aborted"] += 1
        end
        return false
    end
end

"""
    iterative_insert_single_depot!(instance::Instance,
                                    t::Int,
                                    d::Int;
                                    stats::Dict = nothing,
                                    in_LNS::Bool = true,
    )

Try [`insert_single_depot!`](@ref) on pairs of routes sampled on day `t` starting at depot `d`.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_insert_single_depot!(
    instance::Instance, t::Int, d::Int; stats::Dict=nothing, in_LNS::Bool=true
)
    R = nb_routes(instance.solution, t, d)
    nb_it = floor(R^2 * 0.9) # subsample the number of pairs considered
    for it in 1:nb_it
        R = nb_routes(instance.solution, t, d)
        r1 = Random.rand(1:R)
        r2 = Random.rand(1:R)
        if r1 == r2
            continue
        end
        route1 = get_route(instance.solution, t, d, r1)
        route2 = get_route(instance.solution, t, d, r2)
        for i in 1:length(route1.stops)
            improvement_achieved = insert_single_depot!(
                route1, route2, i, instance; stats=stats, in_LNS=in_LNS
            )
            if improvement_achieved
                break
            end
        end
    end
end

"""
    iterative_swap_single_depot!(instance::Instance,
                                    t::Int,
                                    d::Int;
                                    stats::Dict = nothing,
                                    in_LNS::Bool = true,
    )

Try [`swap_single_depot!`](@ref) on pairs of routes sampled on day `t` starting at depot `d`.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_swap_single_depot!(
    instance::Instance, t::Int, d::Int; stats::Dict=nothing, in_LNS::Bool=true
)
    R = nb_routes(instance.solution, t, d)
    nb_it = floor(R^2 * 0.9) # subsample the number of pairs considered
    for it in 1:nb_it
        R = nb_routes(instance.solution, t, d)
        r1 = Random.rand(1:R)
        r2 = Random.rand(1:R)
        if r1 == r2
            continue
        end
        route1 = get_route(instance.solution, t, d, r1)
        route2 = get_route(instance.solution, t, d, r2)
        for i in 1:length(route1.stops), j in 1:length(route2.stops)
            improvement_achieved = swap_single_depot!(
                route1, route2, i, j, instance; stats=stats, in_LNS=in_LNS
            )
            if improvement_achieved
                break
            end
        end
    end
end

"""
    insert_swap_single_depot_routes!(instance::Instance,
                                        verbose::Bool = false;
                                        stats::Dict = nothing,
                                        in_LNS::Bool = true,
    )

Apply [`iterative_insert_single_depot!`](@ref) and [`iterative_swap_single_depot!`](@ref) on every day, depot config.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function insert_swap_single_depot_routes!(
    instance::Instance, verbose::Bool=false; stats::Dict=nothing, in_LNS::Bool=true
)
    @showprogress "Inserts and swaps between routes " for t in 1:(instance.T),
        d in 1:(instance.D)

        iterative_insert_single_depot!(instance, t, d; stats=stats, in_LNS=in_LNS)
        iterative_swap_single_depot!(instance, t, d; stats=stats, in_LNS=in_LNS)
    end
    return verbose && println("Cost after inserts and swaps : ", compute_cost(instance))
end
