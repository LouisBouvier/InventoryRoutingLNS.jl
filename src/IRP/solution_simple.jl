"""
    SimpleSolution

IRP solution as vector of routes.

# Fields
- `routes::Vector{Route}`: routes of the solution.
"""
mutable struct SimpleSolution <: Solution
    routes::Vector{Route}
end

SimpleSolution() = new(Route[])

"""
    list_routes(solution::SimpleSolution)

Get the list of routes in a simple `solution`.
"""
list_routes(solution::SimpleSolution) = solution.routes

"""
    list_routes(solution::SimpleSolution, t::Int)

Get the list of routes starting on day `t` in a simple `solution`.
"""
function list_routes(solution::SimpleSolution, t::Int)
    return filter(route -> route.t == t, list_routes(solution))
end

"""
    list_routes(solution::SimpleSolution, t::Int, d::Int)

Get the list of routes starting on day `t` from depot `d` in a simple `solution`.
"""
function list_routes(solution::SimpleSolution, t::Int, d::Int)
    return filter(route -> route.d == d, list_routes(solution, t))
end

"""
    nb_routes(solution::SimpleSolution)

Get the number of routes in a simple `solution`.
"""
nb_routes(solution::SimpleSolution) = length(solution.routes)

"""
    delete_route!(solution::SimpleSolution, r::Int)

Delete the route at index `r` from a simple `solution`.
"""
delete_route!(solution::SimpleSolution, r::Int) = deleteat!(solution.routes, r)

"""
    add_route!(solution::SimpleSolution, route::Route)

Add `route` to a simple `solution`."""
add_route!(solution::SimpleSolution, route::Route) = push!(solution.routes, route)
