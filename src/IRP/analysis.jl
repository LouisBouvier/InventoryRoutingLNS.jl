## Analyze a solution's average features

"""
    compute_average_content_size(instance::Instance)

Compute the average content size over the routes in the solution of `instance`.

This information can be used as a metric to estimate a solution quality.
"""
function compute_average_content_size(instance::Instance)
    avg_l = (
        sum(content_size(route, instance) for route in list_routes(instance.solution)) /
        nb_routes(instance.solution)
    )
    return avg_l
end

"""
    compute_average_content_size_depot(instance::Instance)

Compute the average content size over the routes that start from each depot in the solution of `instance`.

Return a vector with one value per depot. This information is used for the second path of 
the [`modified_capa_initialization_plus_ls!`](@ref) to estimate the flow arcs' cost.
"""
function compute_average_content_size_depot(instance::Instance)
    D = instance.D
    avg_l = Vector{Float64}(undef, D)
    for d = 1:D
        depot_routes = list_routes_depot(instance.solution, d)
        nb_routes = length(depot_routes)
        if nb_routes > 0
            avg_l[d] =
                (sum(content_size(route, instance) for route in depot_routes) / nb_routes)
        else
            avg_l[d] = instance.vehicle_capacity
        end
    end
    return avg_l
end

"""
    compute_average_content_size_customer(instance::Instance)

Compute the average content size over the routes that visit each depot in the solution of `instance`.

Return a vector with one value per customer. This information is used for the second path of 
the [`modified_capa_initialization_plus_ls!`](@ref) to estimate the flow arcs' cost.
"""
function compute_average_content_size_customer(instance::Instance)
    C = instance.C
    avg_l = Vector{Float64}(undef, C)
    for c = 1:C
        customer_routes = list_routes_customer(instance.solution, c)
        nb_routes = length(customer_routes)
        if nb_routes > 0
            avg_l[c] = (
                sum(content_size(route, instance) for route in customer_routes) / nb_routes
            )
        else
            avg_l[c] = instance.vehicle_capacity
        end
    end
    return avg_l
end

"""
    compute_average_content_size_day(instance::Instance)

Compute the average content size over the routes that start on each day in the solution of `instance`.

Return a vector with one value per day. This information is used for the second path of 
the [`modified_capa_initialization_plus_ls!`](@ref) to estimate the flow arcs' cost.
"""
function compute_average_content_size_day(instance::Instance)
    T = instance.T
    avg_l = Vector{Float64}(undef, T)
    for t = 1:T
        day_routes = list_routes(instance.solution, t)
        nb_routes = length(day_routes)
        if nb_routes > 0
            avg_l[t] =
                sum(content_size(route, instance) for route in day_routes) / nb_routes
        else
            avg_l[t] = instance.vehicle_capacity
        end
    end
    return avg_l
end

"""
    AverageContentSizes

Gather the average content size in the routes of a solution per depot, day and customer. 

Designed to be passed as argument in the second pass of the greedy heuristic 
[`modified_capa_initialization_plus_ls!`](@ref).

# Fields
- `avg_l_d::Vector{Float64}`: average content size per depot.
- `avg_l_c::Vector{Float64}`: average content size per customer.
- `avg_l_t::Vector{Float64}`: average content size per day.
"""
struct AverageContentSizes
    avg_l_d::Vector{Float64}
    avg_l_c::Vector{Float64}
    avg_l_t::Vector{Float64}

    function AverageContentSizes(instance::Instance)
        avg_l_d = compute_average_content_size_depot(instance)
        avg_l_c = compute_average_content_size_customer(instance)
        avg_l_t = compute_average_content_size_day(instance)
        new(avg_l_d, avg_l_c, avg_l_t)
    end
end

"""
    compute_average_nb_km(instance::Instance)

Compute the average number of kilometers of the routes in the solution of `instance`.
"""
function compute_average_nb_km(instance::Instance)
    avg_n = (
        sum(compute_nb_km(route, instance) for route in list_routes(instance.solution)) / nb_routes(instance.solution)
    )
    return avg_n
end

"""
    compute_average_route_duration(instance::Instance)

Compute the average duration in hours of the routes in the solution of `instance`.
"""
function compute_average_route_duration(instance::Instance)
    avg_n = (
        sum(compute_route_duration(route, instance) for route in list_routes(instance.solution)) / nb_routes(instance.solution)
    )
    return avg_n
end

"""
    compute_average_route_duration(instance::Instance, solution::SimpleSolution)

Compute the average duration in hours of the routes in `solution` for `instance`.
"""
function compute_average_route_duration(instance::Instance, solution::SimpleSolution)
    avg_n = (
        sum(compute_route_duration(route, instance) for route in solution.routes) / length(solution.routes)
    )
    return avg_n
end

"""
    compute_route_durations(instance::Instance, solution::SimpleSolution)

Compute the vector of route durations, one element per route of `solution`.
"""
function compute_route_durations(instance::Instance, solution::SimpleSolution)
    durations = [compute_route_duration(route, instance) for route in solution.routes]
    return durations
end

"""
    compute_avg_nb_stops(instance::Instance)

Compute the average number of stops over the routes in the solution of `instance`.
"""
function compute_avg_nb_stops(instance::Instance)
    avg_n = (
        sum(get_nb_stops(route) for route in list_routes(instance.solution)) /
        nb_routes(instance.solution)
    )
    return avg_n
end

"""
    get_most_expensive_customers(instance::Instance)
    
Get the indices of the customers sorted by their costs in the solution.

The cost of a customer is computed as the sum of the inventory [`compute_inventory_cost`](@ref) and 
shortage [`compute_shortage_cost`](@ref) costs.
"""
function get_most_expensive_customers(instance::Instance)
    C = instance.C
    customer_cost = Vector{Int}(undef, C)
    for c = 1:C
        customer = instance.customers[c]
        customer_cost[c] =
            compute_inventory_cost(customer) + compute_shortage_cost(customer)
    end
    return sortperm(customer_cost)
end
