"""
    update_quantities_from_solution!(instance::Instance, m::Int)

Update daily quantities of commodity `m` sent and received from the `instance` solution.

Each route in the solution of `instance` defines deliveries that can be aggregated 
per customer and per depot on each day.
"""
function update_quantities_from_solution!(instance::Instance, m::Int)
    T = instance.T
    for depot in instance.depots
        for t = 1:T
            depot.quantity_sent[m, t] = 0
        end
    end
    for customer in instance.customers
        for t = 1:T
            customer.quantity_received[m, t] = 0
        end
    end

    for route in list_routes(instance.solution)
        t = route.t
        depot = instance.depots[route.d]
        depot.quantity_sent[m, t] += sum(stop.Q[m] for stop in route.stops)
        for stop in route.stops
            t_c = stop.t
            customer = instance.customers[stop.c]
            customer.quantity_received[m, t_c] += stop.Q[m]
        end
    end
end

"""
    update_inventory_from_quantities!(instance::Instance, m::Int)

Update inventories of `m` at depots and customers from quantities sent and received.

When the fields `quantity_received` and `quantity_sent` of `instance` are fixed, 
the daily inventory at each depot and customer can be deduced using the proper dynamics. 
We highlight the demand, release and routes departures are supposed to happen in the 
morning, whereas the reception at the customers is in the evening. Inventories are 
defined in the evening on each day.
"""
function update_inventory_from_quantities!(instance::Instance, m::Int)
    T = instance.T

    for depot in instance.depots
        for t = 1:T
            inventory_prev = t == 1 ? depot.initial_inventory[m] : depot.inventory[m, t - 1]
            depot.inventory[m, t] =
                inventory_prev + depot.production[m, t] - depot.quantity_sent[m, t]
        end
    end
    for customer in instance.customers
        for t = 1:T
            inventory_prev =
                t == 1 ? customer.initial_inventory[m] : customer.inventory[m, t - 1]
            customer.inventory[m, t] =
                max(0, inventory_prev - customer.demand[m, t]) +
                customer.quantity_received[m, t]
        end
    end
end

"""
    update_instance_from_solution!(instance::Instance, m::Int)

Update quantities and inventories of `m` from the routes of `instance` solution.

We first update quantities received and sent from the solution and then update 
inventories from the quantities. 
"""
function update_instance_from_solution!(instance::Instance, m::Int)
    update_quantities_from_solution!(instance, m)
    return update_inventory_from_quantities!(instance, m)
end

"""
    update_quantities_from_solution!(instance::Instance)

Update daily quantities of all commodities sent and received from `instance` solution.

Each route in the solution of `instance` defines deliveries that can be aggregated 
per customer and per depot on each day.
"""
function update_quantities_from_solution!(instance::Instance)
    for m in 1:(instance.M)
        update_quantities_from_solution!(instance, m)
    end
end

"""
    update_inventory_from_quantities!(instance::Instance)

Update inventories of all commodities at depots and customers from quantities sent and received.

When the fields `quantity_received` and `quantity_sent` of `instance` are fixed, 
the daily inventory at each depot and customer can be deduced using the proper dynamics. 
We highlight the demand, release and routes departures are supposed to happen in the 
morning, whereas the reception at the customers is in the evening. Inventories are 
defined in the evening on each day.
"""
function update_inventory_from_quantities!(instance::Instance)
    for m in 1:(instance.M)
        update_inventory_from_quantities!(instance, m)
    end
end

"""
    update_instance_from_solution!(instance::Instance)

Update quantities and inventories of all commodities from the routes of `instance` solution.

We first update quantities received and sent from the solution and then update 
inventories from the quantities. 
"""
function update_instance_from_solution!(instance::Instance)
    update_quantities_from_solution!(instance)
    return update_inventory_from_quantities!(instance)
end

"""
    solved_instance(instance::Instance, solution::Solution)

Create a solved copy of `instance`.

Only useful for additional checks after solving.
"""
function solved_instance(instance::Instance, solution::Solution)
    solved_instance = copy(instance)
    update_instance_from_solution!(solved_instance)
    return solved_instance
end

"""
    reset_solution!(instance::Instance)

Replace the solution of `instance` with an empty one and update inventory.
"""
function reset_solution!(instance::Instance)
    instance.solution = StructuredSolution(instance.T, instance.D)
    return update_instance_from_solution!(instance)
end

"""
    coherence_solution_inventory(instance::Instance)

Check the coherence between the fields of an instance and its solution.
"""
function coherence_solution_inventory(instance::Instance)
    correct_instance = solved_instance(instance, instance.solution)
    ia1 = InstanceArrays(instance)
    ia2 = InstanceArrays(correct_instance)
    depots_coherent = all(ia1.inventory_depots .== ia2.inventory_depots)
    customers_coherent = all(ia1.inventory_customers .== ia2.inventory_customers)
    return depots_coherent && customers_coherent
end


"""
    update_quantities_some_routes!(instance::Instance, 
                                    routes::Vector{Route}, 
                                    action::String
    )

Locally update the quantities sent and received from `routes`.

We apply the same logic as in [`update_quantities_from_solution!`](@ref)
but restricted to the depots and customers that are involved in `routes`.
Depending on `action`, the quantities induced by `routes` can be added or removed.
"""
function update_quantities_some_routes!(
    instance::Instance, routes::Vector{Route}, action::String
)
    depots = instance.depots
    customers = instance.customers
    M = instance.M
    for route in routes
        t = route.t
        depot = depots[route.d]
        for stop in route.stops
            customer = customers[stop.c]
            t_c = stop.t
            for m in 1:M
                @assert stop.Q[m] == 0 || uses_commodity(depot, m)
                if action == "add"
                    depot.quantity_sent[m, t] += stop.Q[m]
                elseif action == "delete"
                    depot.quantity_sent[m, t] -= stop.Q[m]
                end
            end
            for m in 1:M
                @assert stop.Q[m] == 0 || uses_commodity(customer, m)
                if action == "add"
                    customer.quantity_received[m, t_c] += stop.Q[m]
                elseif action == "delete"
                    customer.quantity_received[m, t_c] -= stop.Q[m]
                end
            end
        end
    end
end

"""
    update_inventories_some_routes!(instance::Instance, routes::Vector{Route})

Locally update the inventories from the quantities sent by `routes`.

We apply the same logic as in [`update_inventory_from_quantities!`](@ref)
but restricted to the days, commodities, depots and customers that must be considered.
The period affected is from the first departure date of the `routes` to the horizon `T`
"""
function update_inventories_some_routes!(instance::Instance, routes::Vector{Route})
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    ds = distinct(route.d for route in routes)
    cs = distinct(stop.c for route in routes for stop in route.stops)
    ms = [m for m = 1:M if any(uses_commodity(route, m) for route in routes)]
    first_departure_date = minimum(route.t for route in routes)
    ts = first_departure_date:T
    for d in ds
        depot = instance.depots[d]
        for m in ms
            if uses_commodity(depot, m)
                for t in ts
                    previous_inventory =
                        t == 1 ? depot.initial_inventory[m] : depot.inventory[m, t-1]
                    depot.inventory[m, t] = (
                        previous_inventory + depot.production[m, t] -
                        depot.quantity_sent[m, t]
                    )
                end
            end
        end
    end
    for c in cs
        customer = instance.customers[c]
        for m in ms
            if uses_commodity(customer, m)
                for t in ts
                    previous_inventory =
                        t == 1 ? customer.initial_inventory[m] : customer.inventory[m, t-1]
                    customer.inventory[m, t] = (
                        max(0, previous_inventory - customer.demand[m, t]) +
                        customer.quantity_received[m, t]
                    )
                end
            end
        end
    end
end

"""
    update_instance_some_routes!(instance::Instance, 
                                    routes::Vector{Route}, 
                                    action::String, 
                                    alter_solution::Bool=true
    )

Locally update the `instance` inventories and quantities from `routes`.

We first apply [`update_quantities_some_routes!`](@ref) to update the quantities 
locally depending on the `action`, then propagate the quantities to inventories
with [`update_inventories_some_routes!`](@ref). When `alter_solution` is true 
we also add or delete the `routes` from the solution currently stored in the `instance`.
"""
function update_instance_some_routes!(
    instance::Instance, routes::Vector{Route}, action::String, alter_solution::Bool=true
)
    update_quantities_some_routes!(instance, routes, action)
    update_inventories_some_routes!(instance, routes)
    if alter_solution
        for route in routes
            if action == "add"
                add_route!(instance.solution, route)
            elseif action == "delete"
                delete_route!(instance.solution, route)
            end
        end
    end
end
