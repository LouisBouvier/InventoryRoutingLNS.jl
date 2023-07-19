"""
    StructuredSolution

IRP solution as matrix of routes per day and depot.

# Fields
- `routes_per_day_and_depot::Matrix{Vector{Route}}`: routes of the solution.
"""
mutable struct StructuredSolution <: Solution
    routes_per_day_and_depot::Matrix{Vector{Route}}
end

## Constructor

function StructuredSolution(T::Int, D::Int)
    routes_per_day_and_depot = Matrix{Vector{Route}}(undef, T, D)
    for t in 1:T, d in 1:D
        routes_per_day_and_depot[t, d] = Route[]
    end
    return StructuredSolution(routes_per_day_and_depot)
end

## Copy
"""
    Base.copy(solution::StructuredSolution)

Copy structured `solution`.
"""
function Base.copy(solution::StructuredSolution)
    return StructuredSolution([
        [copy(route) for route in list_routes(solution, t, d)] for t in 1:get_T(solution),
        d in 1:get_D(solution)
    ])
end

## Copy custom 
"""
    mycopy(solution::StructuredSolution)

Custom copy of a structured `solution`.
"""
function mycopy(solution::StructuredSolution)
    return StructuredSolution([
        [mycopy(route) for route in list_routes(solution, t, d)] for t in 1:get_T(solution),
        d in 1:get_D(solution)
    ])
end

## Counting
"""
    get_T(solution::StructuredSolution)

Get the horizon `T` from the structured `solution`.
"""
get_T(solution::StructuredSolution) = size(solution.routes_per_day_and_depot, 1)

"""
    get_D(solution::StructuredSolution)

Get the number of depots `D` from the structured `solution`.
"""
get_D(solution::StructuredSolution) = size(solution.routes_per_day_and_depot, 2)

"""
    nb_routes(solution::StructuredSolution)

Compute the number of routes in a structured `solution`.
"""
function nb_routes(solution::StructuredSolution)
    return sum(length.(solution.routes_per_day_and_depot))
end

"""
    nb_routes(solution::StructuredSolution, t::Int)

Compute the number of routes starting on day `t` in a structured `solution`.
"""
function nb_routes(solution::StructuredSolution, t::Int)
    return sum(length.(@view solution.routes_per_day_and_depot[t, :]))
end

"""
    nb_routes(solution::StructuredSolution, t::Int, d::Int)

Compute the number of routes starting on day `t` from depot `d` in a structured `solution`.
"""
function nb_routes(solution::StructuredSolution, t::Int, d::Int)
    return length(solution.routes_per_day_and_depot[t, d])
end

"""
    nb_routes_depot(solution::StructuredSolution, d::Int)

Compute the number of routes starting from depot `d` in a structured `solution`.
"""
function nb_routes_depot(solution::StructuredSolution, d::Int)
    return sum(length.(@view solution.routes_per_day_and_depot[:, d]))
end

"""
    nb_routes_customer(solution::StructuredSolution, t::Int, c::Int)

Compute the number of routes that visit customer `c` and start on day `t` in a structured `solution`.
"""
function nb_routes_customer(solution::StructuredSolution, t::Int, c::Int)
    count = 0
    routes_of_the_day = list_routes(solution, t)
    for route in routes_of_the_day
        if c in unique_stops(route)
            count += 1
        end
    end
    return count
end

## List of routes

"""
    list_routes(solution::StructuredSolution, t::Int, d::Int)

Get the list of routes starting on day `t` from depot `d` in a structured `solution`.
"""
function list_routes(solution::StructuredSolution, t::Int, d::Int)
    return solution.routes_per_day_and_depot[t, d]
end

"""
    list_routes(solution::StructuredSolution, t::Int)

Get the list of routes starting on day `t` in a structured `solution`.
"""
function list_routes(solution::StructuredSolution, t::Int)
    routes = Vector{Route}(undef, nb_routes(solution, t))
    r = 0
    for d in 1:get_D(solution)
        for route in list_routes(solution, t, d)
            r += 1
            routes[r] = route
        end
    end
    return routes
end

"""
    list_routes(solution::StructuredSolution)

Get the list of routes of a structured `solution`.
"""
function list_routes(solution::StructuredSolution)
    routes = Vector{Route}(undef, nb_routes(solution))
    r = 0
    for t in 1:get_T(solution), d in 1:get_D(solution)
        for route in list_routes(solution, t, d)
            r += 1
            routes[r] = route
        end
    end
    return routes
end

"""
    list_routes_depot(solution::StructuredSolution, d::Int)

Get the list of routes starting by depot `d` in a structured `solution`.
"""
function list_routes_depot(solution::StructuredSolution, d::Int)
    routes = Vector{Route}(undef, sum(nb_routes(solution, t, d) for t in 1:get_T(solution)))
    r = 0
    for t in 1:get_T(solution)
        for route in list_routes(solution, t, d)
            r += 1
            routes[r] = route
        end
    end
    return routes
end

"""
    list_routes_customer(solution::StructuredSolution, c::Int)

Get the list of routes visiting customer `c` in a structured `solution`.
"""
function list_routes_customer(solution::StructuredSolution, c::Int)
    routes = Vector{Route}()
    for route in list_routes(solution)
        for stop in route.stops
            if stop.c == c
                routes = vcat(routes, [route])
            end
        end
    end
    return routes
end

"""
    list_routes_customer(solution::StructuredSolution, c::Int, t::Int)

Get the list of routes visiting customer `c` and starting on day `t` in a structured `solution`.
"""
function list_routes_customer(solution::StructuredSolution, c::Int, t::Int)
    routes = Vector{Route}()
    places = Vector{Int}()
    for route in list_routes(solution, t)
        for (s, stop) in enumerate(route.stops)
            if stop.c == c
                routes = vcat(routes, [route])
                places = vcat(places, [s])
            end
        end
    end
    return routes, places
end

"""
    get_route(solution::StructuredSolution, t::Int, d::Int, r::Int)

Get the `r`-th route starting on day `t` by depot `d` in a structured `solution`.
"""
function get_route(solution::StructuredSolution, t::Int, d::Int, r::Int)
    return list_routes(solution, t, d)[r]
end

"""
    get_route_depot(solution::StructuredSolution, d::Int, r::Int)

Get the `r`-th route starting by depot `d` in a structured `solution`.
"""
function get_route_depot(solution::StructuredSolution, d::Int, r::Int)
    return list_routes_depot(solution, d)[r]
end

"""
    get_route_day(solution::StructuredSolution, t::Int, r::Int)

Get the `r`-th route starting on day `t` in a structured `solution`.
"""
function get_route_day(solution::StructuredSolution, t::Int, r::Int)
    return list_routes(solution, t)[r]
end

## Add and delete routes

"""
    add_route!(solution::StructuredSolution, route::Route)

Push `route` to a structured `solution`.
"""
function add_route!(solution::StructuredSolution, route::Route)
    return push!(solution.routes_per_day_and_depot[route.t, route.d], route)
end

"""
    add_route!(solution::StructuredSolution, routes::Vector{Route})

Push a set `routes` to a structured `solution`.
"""
function add_route!(solution::StructuredSolution, routes::Vector{Route})
    return all(
        push!(solution.routes_per_day_and_depot[route.t, route.d], route) for
        route in routes
    )
end

"""
    delete_route!(solution::StructuredSolution, t::Int, d::Int, r::Int)

Delete the `r`-th route starting on day `t` by depot `d` from a structured `solution`.
"""
function delete_route!(solution::StructuredSolution, t::Int, d::Int, r::Int)
    return deleteat!(solution.routes_per_day_and_depot[t, d], r)
end

"""
    delete_routes!(solution::StructuredSolution, t::Int, d::Int, rs)

Delete the `rs`-th routes starting on day `t` by depot `d` from a structured `solution`.
"""
function delete_routes!(solution::StructuredSolution, t::Int, d::Int, rs)
    return deleteat!(solution.routes_per_day_and_depot[t, d], rs)
end

"""
    delete_route!(solution::StructuredSolution, route::Route)

Delete `route` from a structured `solution`.
"""
function delete_route!(solution::StructuredSolution, route::Route)
    t, d = route.t, route.d
    for r in 1:nb_routes(solution, t, d)
        if get_route(solution, t, d, r).id == route.id
            delete_route!(solution, t, d, r)
            return true
        end
    end
    return false
end

"""
    delete_routes!(solution::StructuredSolution, routes::Vector{Route})

Delete a set `routes` from a structured `solution`.
"""
function delete_routes!(solution::StructuredSolution, routes::Vector{Route})
    return all(delete_route!(solution, route) for route in routes)
end
