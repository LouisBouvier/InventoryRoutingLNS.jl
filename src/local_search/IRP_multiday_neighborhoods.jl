"""
    change_day!(instance::Instance, 
                route::Route, 
                new_t::Int; 
                stats::Dict = nothing
    )

Change the departure day of `route` to `new_t`.

Only possible one day in the past or in the future.
Feasible if the last day of arrival is before the horizon `T` 
and if the `route` depot has nonnegative inventory when moving
to the past. 
Applied if feasible and cost is reduced.
"""
function change_day!(instance::Instance, route::Route, new_t::Int; stats::Dict=nothing)
    # Parameters 
    M, T = instance.M, instance.T
    t = route.t
    if new_t > t && route.stops[end].t + (new_t - t) > T
        stats["change_day_aborted"] += 1
        return false
    end
    d = route.d
    ds = [d]
    cs = unique(stop.c for stop in route.stops)
    ms = [m for m in 1:M if uses_commodity(route, m)]
    new_route = mycopy(route)
    new_route.t = new_t
    for stop in new_route.stops
        stop.t += new_t - t
    end
    if new_t == t - 1
        quantities = sum(stop.Q for stop in route.stops)
        feasible = all(instance.depots[d].inventory[:, t - 1] .- quantities .>= 0)
        if feasible
            oldcost = compute_cost(
                instance;
                ds=ds,
                cs=cs,
                ms=ms,
                ts=collect(new_t:T),
                solution=SimpleSolution([]),
            )
            update_instance_some_routes!(instance, [route], "delete", false)
            update_instance_some_routes!(instance, [new_route], "add", false)
            newcost = compute_cost(
                instance;
                ds=ds,
                cs=cs,
                ms=ms,
                ts=collect(new_t:T),
                solution=SimpleSolution([]),
            )
            update_instance_some_routes!(instance, [new_route], "delete", false)
            update_instance_some_routes!(instance, [route], "add", false)
            if newcost - oldcost < 0
                update_instance_some_routes!(instance, [route], "delete")
                update_instance_some_routes!(instance, [new_route], "add")
                stats["gain_change_day"] += newcost - oldcost
                stats["change_day_applied"] += 1
                # println("change_day applied")
                return true
            else
                stats["change_day_aborted"] += 1
                return false
            end
        else
            stats["change_day_aborted"] += 1
            return false
        end
    elseif new_t == t + 1
        feasible = new_route.stops[end].t <= T
        if feasible
            oldcost = compute_cost(
                instance; ds=ds, cs=cs, ms=ms, ts=collect(t:T), solution=SimpleSolution([])
            )
            update_instance_some_routes!(instance, [route], "delete", false)
            update_instance_some_routes!(instance, [new_route], "add", false)
            newcost = compute_cost(
                instance; ds=ds, cs=cs, ms=ms, ts=collect(t:T), solution=SimpleSolution([])
            )
            update_instance_some_routes!(instance, [new_route], "delete", false)
            update_instance_some_routes!(instance, [route], "add", false)
        else
            newcost = Inf
        end
        if newcost - oldcost < 0
            # println("change_day applied")
            update_instance_some_routes!(instance, [route], "delete")
            update_instance_some_routes!(instance, [new_route], "add")
            stats["gain_change_day"] += newcost - oldcost
            stats["change_day_applied"] += 1
            return true
        else
            stats["change_day_aborted"] += 1
            return false
        end
    end
end

"""
    change_day_all_one_pass!(instance::Instance,
                                direction::String = "ahead";
                                stats::Dict = nothing,
    )

Test [`change_day!`](@ref) on every route of the solution.

The `direction` can either be `"ahead"`, `"back"` or `"random"`.
When random, we observe the realization of a Bernoulli random 
variable with parameter `p = 0.5` and move ahead or back.
"""
function change_day_all_one_pass!(
    instance::Instance, direction::String="ahead"; stats::Dict=nothing
)
    routes = list_routes(instance.solution)
    T = instance.T
    improved = false
    if direction == "ahead"
        @showprogress "Change days towards future: " for route in routes
            t = route.t
            if t < T
                locally_improved = change_day!(instance, route, t + 1; stats=stats)
                improved = improved || locally_improved
            end
        end
    elseif direction == "back"
        @showprogress "Change days towards past: " for route in routes
            t = route.t
            if t > 1
                locally_improved = change_day!(instance, route, t - 1; stats=stats)
                improved = improved || locally_improved
            end
        end
    elseif direction == "random"
        # toss a coin per route, move ahead or back depending on the result
        @showprogress "Change days at random: " for route in routes
            if Random.rand(Float64, 1)[1] < 0.5
                t = route.t
                if t < T
                    locally_improved = change_day!(instance, route, t + 1; stats=stats)
                    improved = improved || locally_improved
                end
            else
                t = route.t
                if t > 1
                    locally_improved = change_day!(instance, route, t - 1; stats=stats)
                    improved = improved || locally_improved
                end
            end
        end
    end
    return improved
end

"""
    iterative_change_day!(instance::Instance, 
                            direction::String = "ahead"; 
                            stats::Dict = nothing
    )

Apply [`change_day_all_one_pass!`](@ref) until no improvement is found.
"""
function iterative_change_day!(
    instance::Instance, direction::String="ahead"; stats::Dict=nothing
)
    improvement = true
    while improvement
        improvement = change_day_all_one_pass!(instance, direction; stats=stats)
    end
end
