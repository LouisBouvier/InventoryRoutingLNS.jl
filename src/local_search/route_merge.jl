"""
    concatenate(routes::Vector{Route})

Concatenate `routes` that share the same depot and departure date.
"""
function concatenate(routes::Vector{Route})
    t, d = routes[1].t, routes[1].d
    for route in routes
        if route.t != t || route.d != d
            error("Routes with different days or depots")
        end
    end
    return Route(; t=t, d=d, stops=[copy(stop) for route in routes for stop in route.stops])
end

function merge_plausible(route1::Route, route2::Route, instance::Instance)
    if content_size(route1, instance) + content_size(route2, instance) >
        instance.vehicle_capacity
        return false
    elseif length(unique_stops([route1, route2])) > instance.S_max
        return false
    else
        return true
    end
end

function merge(route1::Route, route2::Route, instance::Instance)
    newroute = concatenate([copy(route1), copy(route2)])
    update_route_order!(newroute, instance, collect(1:get_nb_stops(newroute)))
    # optimize_route!(newroute, instance)
    compress!(newroute, instance)
    return newroute
end

"""
    gain_merge(route1::Route, 
                route2::Route, 
                instance::Instance
    )::Float64

Compute the cost gain of merging two routes having same starting depot and day.

`Inf` if infeasible.
"""
function gain_merge(route1::Route, route2::Route, instance::Instance)::Float64
    if merge_plausible(route1, route2, instance)
        # Parameters
        M, T = instance.M, instance.T
        # Localize and compute old cost
        cs = unique_stops([route1, route2])
        departure_date = route1.t
        ts = collect(departure_date:T)
        ms = [m for m in 1:M if (uses_commodity(route1, m) || uses_commodity(route2, m))]
        oldcost = compute_cost(
            instance;
            ds=Vector{Int}(),
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([route1, route2]),
        )
        newroute = merge(route1, route2, instance)
        if feasibility(newroute, instance)
            update_instance_some_routes!(instance, [route1, route2], "delete", false)
            update_instance_some_routes!(instance, [newroute], "add", false)
            newcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([newroute]),
            )
            update_instance_some_routes!(instance, [newroute], "delete", false)
            update_instance_some_routes!(instance, [route1, route2], "add", false)
            return newcost - oldcost
        else
            return Inf
        end
    else
        return Inf
    end
end

"""
    evaluate_all_merges(instance::Instance, 
                        t::Int, 
                        d::Int
    )

Evaluate all the possible merges related to `d` and `t` in the current solution.

`Inf` if infeasible.
"""
function evaluate_all_merges(instance::Instance, t::Int, d::Int)
    R = nb_routes(instance.solution, t, d)
    Δ = fill(Inf, R, R)
    for r1 in 1:R, r2 in 1:(r1 - 1)
        route1 = get_route(instance.solution, t, d, r1)
        route2 = get_route(instance.solution, t, d, r2)
        Δ[r1, r2] = gain_merge(route1, route2, instance)
    end
    return Δ
end

"""
    perform_best_merge!(instance::Instance,
                        t::Int,
                        d::Int,
                        Δ::Matrix{Float64};
                        stats::Dict = nothing,
                        in_LNS::Bool = true,
    )

Perform the best merge over the routes related to the same depot `d` and departure date `t`.

In `Δ` we store the gain of merge for each pair of routes, iteratively updated.
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function perform_best_merge!(
    instance::Instance,
    t::Int,
    d::Int,
    Δ::Matrix{Float64};
    stats::Dict=nothing,
    in_LNS::Bool=true,
)
    R = nb_routes(instance.solution, t, d)
    if R > 1 && minimum(Δ) < -0.5
        r1, r2 = Tuple(argmin(Δ))
        route1 = get_route(instance.solution, t, d, r1)
        route2 = get_route(instance.solution, t, d, r2)
        @assert merge_plausible(route1, route2, instance)
        newroute = merge(route1, route2, instance)
        # we update the instance and solution separately to keep the routes order
        update_instance_some_routes!(instance, [route1, route2], "delete", false)
        update_instance_some_routes!(instance, [newroute], "add", false)
        delete_routes!(instance.solution, t, d, [r2, r1])
        add_route!(instance.solution, newroute)

        new_Δ = Matrix{Float64}(undef, R - 1, R - 1)

        oldr = [r for r in 1:R if (r != r1 && r != r2)]
        new_Δ[1:(R - 2), 1:(R - 2)] = @view Δ[oldr, oldr]
        for r in 1:(R - 2)
            route = get_route(instance.solution, t, d, r)
            new_Δ[R - 1, r] = gain_merge(newroute, route, instance)
        end
        new_Δ[1:(R - 1), R - 1] .= Inf
        if in_LNS
            stats["gain_merge"] += minimum(Δ)
        end
        return true, new_Δ
    else
        return false, Δ
    end
end

"""
    iterative_merge!(instance::Instance,
                        t::Int,
                        d::Int;
                        stats::Dict = nothing,
                        in_LNS::Bool = true,
    )

Apply [`perform_best_merge!`](@ref) on depot `d` and day `t` until no improvement found.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_merge!(
    instance::Instance, t::Int, d::Int; stats::Dict=nothing, in_LNS::Bool=true
)
    Δ = evaluate_all_merges(instance, t, d)
    while true
        improvement_found, Δ = perform_best_merge!(
            instance, t, d, Δ; stats=stats, in_LNS=in_LNS
        )
        if !improvement_found
            break
        end
    end
end

"""
    iterative_merge!(instance::Instance,
                        verbose::Bool = false;
                        stats::Dict = nothing,
                        in_LNS::Bool = true,
    )

Apply [`perform_best_merge!`](@ref) on every depot and day until no improvement found.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_merge!(
    instance::Instance, verbose::Bool=false; stats::Dict=nothing, in_LNS::Bool=true
)
    @showprogress "Greedy routes merge " for t in 1:(instance.T), d in 1:(instance.D)
        iterative_merge!(instance, t, d; stats=stats, in_LNS=in_LNS)
    end
    return verbose && println("Cost after merge : ", compute_cost(instance))
end
