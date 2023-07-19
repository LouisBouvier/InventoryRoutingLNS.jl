"""
    TSP_neighborhood!(;route::Route, 
                        instance::Instance, 
                        neighborhood_index::Int, 
                        index_1::Int, 
                        index_2::Int, 
                        stats::Dict, 
                        in_LNS::Bool
    )

Apply one of the three following TSP neighborhoods to `route`: `relocate`, `swap`, `2-opt*`.

Each neighborhood involves two indices `index_1` and `index_2`. We use `neighborhood_index` 
to choose to apply `relocate` (1), `swap` (2) or `two_opt_star` (3).
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function TSP_neighborhood!(;
    route::Route,
    instance::Instance,
    neighborhood_index::Int,
    index_1::Int,
    index_2::Int,
    stats::Dict,
    in_LNS::Bool,
)
    neighborhood_names = ["relocate", "swap", "two_opt_star"]
    neighborhood_name = neighborhood_names[neighborhood_index]
    # Parameters 
    M, T = instance.M, instance.T
    # Consider affected variables
    departure_time = route.t
    cs = unique_stops(route)
    ms = [m for m in 1:M if uses_commodity(route, m)]
    ts = collect(departure_time:T)
    route_modified = mycopy(route)
    # Find the corresponding stops order
    permutation = collect(1:length(route.stops))
    if neighborhood_index == 1
        deleteat!(permutation, index_1)
        position_for_insertion = findfirst(x -> x == index_2, permutation) + 1
        insert!(permutation, position_for_insertion, index_1)
    elseif neighborhood_index == 2
        permutation[index_1], permutation[index_2] = index_2, index_1
    else
        permutation[index_1:index_2] = collect(Iterators.reverse(index_1:index_2))
    end
    # Update the route and compute local cost
    update_route_order!(route_modified, instance, permutation)
    @assert(feasibility(route, instance))
    oldcost = compute_cost(
        instance; ds=Vector{Int}(), cs=cs, ms=ms, ts=ts, solution=SimpleSolution([route])
    )
    if feasibility(route_modified, instance)
        update_instance_some_routes!(instance, [route], "delete", false)
        update_instance_some_routes!(instance, [route_modified], "add", false)
        newcost = compute_cost(
            instance;
            ds=Vector{Int}(),
            cs=cs,
            ms=ms,
            ts=ts,
            solution=SimpleSolution([route_modified]),
        )
        update_instance_some_routes!(instance, [route_modified], "delete", false)
        update_instance_some_routes!(instance, [route], "add", false)
    else
        newcost = Inf
    end
    if newcost < oldcost
        update_instance_some_routes!(instance, [route], "delete", false)
        update_instance_some_routes!(instance, [route_modified], "add", false)
        route.stops = route_modified.stops
        if in_LNS
            stats["gain_" * neighborhood_name] += newcost - oldcost
            stats[neighborhood_name * "_applied"] += 1
        end
        return true
    else
        if in_LNS
            stats[neighborhood_name * "_aborted"] += 1
        end
        return false
    end
end

"""
    iterative_TSP_neighborhood!(;route::Route, 
                                instance::Instance, 
                                neighborhood_index::Int, 
                                stats::Dict, 
                                in_LNS::Bool
    )

Iteratively apply a TSP neighborhood to the stops of `route` untill no improvement.

We use `neighborhood_index` to choose to apply `relocate` (1), `swap` (2) or `two_opt_star` (3).
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function iterative_TSP_neighborhood!(;
    route::Route, instance::Instance, neighborhood_index::Int, stats::Dict, in_LNS::Bool
)
    improvement = true
    while improvement
        improvement = false
        for ind1 in shuffle(collect(1:length(route.stops)))
            for ind2 in shuffle(collect(1:length(route.stops)))
                if ind2 == ind1
                    continue
                else
                    updated = TSP_neighborhood!(;
                        route=route,
                        instance=instance,
                        neighborhood_index=neighborhood_index,
                        index_1=ind1,
                        index_2=ind2,
                        stats=stats,
                        in_LNS=in_LNS,
                    )
                    if updated
                        improvement = true
                        continue
                    end
                end
            end
        end
    end
end
