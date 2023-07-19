"""
    delete_non_profitable_routes!(instance::Instance, 
                                    t::Int, 
                                    d::Int
    )

Delete routes starting on day `t` by depot `d` when the total cost decreases.

Not used in the current version.
"""
function delete_non_profitable_routes!(instance::Instance, t::Int, d::Int)
    room_for_improvement = true
    while room_for_improvement
        room_for_improvement = false
        for route in sort(
            list_routes(instance.solution, t, d);
            by=route -> compute_route_cost(route, instance),
            rev=true,
        )
            ds, cs = [d], [stop.c for stop in route.stops]
            oldcost = compute_cost(instance; ds=ds, cs=cs, solution=SimpleSolution([route]))
            update_instance_some_routes!(instance, [route], "delete")
            newcost = compute_cost(instance; ds=ds, cs=cs, solution=SimpleSolution(Route[]))
            feasible = feasibility(instance; ds=ds, cs=cs, solution=SimpleSolution(Route[]))
            if feasible && newcost < oldcost
                room_for_improvement = true
                break
            else
                update_instance_some_routes!(instance, [route], "add")
            end
        end
    end
end

"""
    delete_non_profitable_routes!(instance::Instance,
                                    t::Int;
                                    stats::Dict = nothing,
                                    in_LNS::Bool = true,
    )

Delete routes starting on day `t` when the total cost decreases.

The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function delete_non_profitable_routes!(
    instance::Instance, t::Int; stats::Dict=nothing, in_LNS::Bool=true
)
    room_for_improvement = true
    while room_for_improvement
        room_for_improvement = false
        gains = fill(Inf, nb_routes(instance.solution, t))
        for (rt, route) in enumerate(list_routes(instance.solution, t))
            ds, cs = [route.d], [stop.c for stop in route.stops]
            oldcost = compute_cost(instance; ds=ds, cs=cs, solution=SimpleSolution([route]))
            update_instance_some_routes!(instance, [route], "delete")
            if feasibility(instance; ds=ds, cs=cs, solution=SimpleSolution(Route[]))
                newcost = compute_cost(
                    instance; ds=ds, cs=cs, solution=SimpleSolution(Route[])
                )
                gains[rt] = newcost - oldcost
            end
            update_instance_some_routes!(instance, [route], "add")
        end
        if length(gains) > 0 && minimum(gains) < 0
            rt = argmin(gains)
            route = list_routes(instance.solution, t)[rt]
            update_instance_some_routes!(instance, [route], "delete")
            if in_LNS
                stats["gain_delete_route"] += minimum(gains)
            end
            room_for_improvement = true
        end
    end
end

"""
    delete_non_profitable_routes!(instance::Instance,
                                    verbose::Bool = false;
                                    stats::Dict = nothing,
                                     in_LNS::Bool = true,
    )

Apply [`delete_non_profitable_routes!`](@ref) every day.
"""
function delete_non_profitable_routes!(
    instance::Instance, verbose::Bool=false; stats::Dict=nothing, in_LNS::Bool=true
)
    @showprogress "Delete non profitable routes " for t in (instance.T):-1:1
        delete_non_profitable_routes!(instance, t; stats=stats, in_LNS=in_LNS)
    end
    return verbose &&
           println("Cost after deleting non profitable routes : ", compute_cost(instance))
end
