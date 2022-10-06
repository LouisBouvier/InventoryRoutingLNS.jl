## Commodity flow graph for one customer
"""
    add_artificial_nodes_CFGC!(fg::FlowGraph)

Add the artificial nodes to the commodity flow graph `fg` of a customer.

These artificial nodes are used to build a flow problem.
- The `source` and `sink` nodes enable a circulation.
- `production` is a way to model and force the value of depots release with capacitated arcs.
- `demand` does the same for the customers demand.
- `initial_inventory` enables to set the initial inventory at each depot and each customer.
- `shortage_compensation` is a way to model the shortage costs in the flow.
- `delivery_other_customers` enables to fix the quantities to be sent by depots to other customers than the one being inserted.
- `final_inventory` gathers the inventory at each site in the end of the horizon `T`.
"""
function add_artificial_nodes_CFGC!(fg::FlowGraph)
    add_vertex!(fg, FGN(str = "source"))

    add_vertex!(fg, FGN(str = "production"))
    add_vertex!(fg, FGN(str = "initial_inventory"))
    add_vertex!(fg, FGN(str = "shortage_compensation"))

    add_vertex!(fg, FGN(str = "demand"))
    add_vertex!(fg, FGN(str = "delivery_other_customers"))
    add_vertex!(fg, FGN(str = "final_inventory"))

    add_vertex!(fg, FGN(str = "sink"))
end

"""
    add_every_day_nodes_CFGC!(fg::FlowGraph;
                                instance::Instance,
                                customer_index::Int,
                                routes::Vector{Route},
                                dates::Vector,
                                costs::Vector,    
    )

Add the daily inventory nodes to the commodity flow graph of a customer.

We update `fg` with new nodes:
- One `morning` and `evening` node on each day `t` for each site. We remind that demand, 
    release and routes departures occur in the morning, whereas routes arrival in the evening. 
- One `free_night` node on each day to incorporate the excess inventory costs.
- One node per possible position of the customer to insert in the `routes`. 
    This means saving the arrival dates for each position in `dates`.
"""
function add_every_day_nodes_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    customer_index::Int,
    routes::Vector{Route},
    dates::Vector,
    costs::Vector,    
)

    D, T = instance.D, instance.T

    for t = 1:T
        # Depots
        for d = 1:D
            add_vertex!(fg, FGN(t = t, d = d, str = "morning"))
            add_vertex!(fg, FGN(t = t, d = d, str = "evening"))
            add_vertex!(fg, FGN(t = t, d = d, str = "free_night"))
        end
        # Customers
        add_vertex!(fg, FGN(t = t, c = customer_index, str = "morning"))
        add_vertex!(fg, FGN(t = t, c = customer_index, str = "evening"))
        add_vertex!(fg, FGN(t = t, c = customer_index, str = "free_night"))
    end
    # Nodes of the last day
    for d = 1:D
        add_vertex!(fg, FGN(t = T + 1, d = d, str = "morning"))
    end
    add_vertex!(fg, FGN(t = T + 1, c = customer_index, str = "morning"))

    # Nodes for the existing routes
    for (r, route) in enumerate(routes)
        add_vertex!(fg, FGN(t = route.t, str = "route_$r"))
        for i = 1:(get_nb_stops(route)+1)
            if costs[r][i] != -1
                add_vertex!(fg, FGN(t = dates[r][i], c = customer_index, s = i, str = "route_$r"))
            end
        end
    end
end

"""
    add_initial_final_inventory_arcs_CFGC!(fg::FlowGraph;
                                            instance::Instance,
                                            customer_index::Int,
                                            commodity_index::Int,
    )

Add arcs between the artificial nodes and initial and final inventory nodes.

The arcs from `initial_inventory` to the morning of the first day are used to set
the initial inventories to the values stored in `instance`. 
The final inventories are aggregated for clarity and could be used to add final 
inventory costs for instance.
"""
function add_initial_final_inventory_arcs_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    customer_index::Int,
    commodity_index::Int,
)
    D, T = instance.D, instance.T

    # Initial inventory depots
    for d = 1:D
        n1 = FGN(str = "initial_inventory")
        n2 = FGN(t = 1, d = d, str = "morning")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.depots[d].initial_inventory[commodity_index])
    end

    # Initial inventory
    n1 = FGN(str = "initial_inventory")
    n2 = FGN(t = 1, c = customer_index, str = "morning")
    add_edge!(fg, n1, n2)
    set_value!(
        fg,
        ne(fg),
        instance.customers[customer_index].initial_inventory[commodity_index],
    )

    # Final inventory depots
    for d = 1:D
        n1 = FGN(t = T + 1, d = d, str = "morning")
        n2 = FGN(str = "final_inventory")
        add_edge!(fg, n1, n2)
    end

    # Final inventory customers
    n1 = FGN(t = T + 1, c = customer_index, str = "morning")
    n2 = FGN(str = "final_inventory")
    add_edge!(fg, n1, n2)
end

"""
    add_production_delivery_arcs_depots_CFGC!(fg::FlowGraph;
                                                instance::Instance,
                                                commodity_index::Int,
    )

Add the arcs corresponding to release and quantities to send to other customers.

We use the arcs from `production` to the morning of each day to set the release
of each customer in accordance with the data stored in `instance`.
Besides, since we fix a part of the solution when optimizing the reinsertion of 
one customer, the arcs to `delivery_other_customers` nodes are used to take the 
other deliveries into account in the inventory dynamics of the depots.
"""
function add_production_delivery_arcs_depots_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
)
    D, T = instance.D, instance.T

    # Production depots
    for t = 1:T, d = 1:D
        n1 = FGN(str = "production")
        n2 = FGN(t = t, d = d, str = "morning")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.depots[d].production[commodity_index, t])
    end

    # Delivery of the other customers
    for t = 1:T, d = 1:D
        n1 = FGN(t = t, d = d, str = "morning")
        n2 = FGN(str = "delivery_other_customers")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.depots[d].quantity_sent[commodity_index, t])
    end
end

"""
    add_shortage_demand_arcs_customer_CFGC!(fg::FlowGraph;
                                            instance::Instance,
                                            customer_index::Int,
                                            commodity_index::Int,
    )

Add the arcs corresponding to demand and shortage.

As for the release, the arcs from each morning to the node `demand`
are used to fix the demand in accordance with the data of `instance`.
Besides, we create arcs from the node `shortage_compensation` to each morning 
node with shortage cost to model the soft minimum inventory constraint. 
"""
function add_shortage_demand_arcs_customer_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    customer_index::Int,
    commodity_index::Int,
)
    D, T = instance.D, instance.T

    # Shortage customers
    for t = 1:T
        n1 = FGN(str = "shortage_compensation")
        n2 = FGN(t = t, c = customer_index, str = "morning")
        add_edge!(fg, n1, n2)
        set_cost!(
            fg,
            ne(fg),
            instance.customers[customer_index].shortage_cost[commodity_index],
        )
    end

    # Demand customers
    for t = 1:T
        n1 = FGN(t = t, c = customer_index, str = "morning")
        n2 = FGN(str = "demand")
        add_edge!(fg, n1, n2)
        set_value!(
            fg,
            ne(fg),
            instance.customers[customer_index].demand[commodity_index, t],
        )
    end
end

"""
    add_depots_inventory_arcs_CFGC!(fg::FlowGraph;
                                    instance::Instance,
                                    commodity_index::Int,
    )

Add the arcs corresponding to the depots inventory dynamics.

Thanks to the `free_night` nodes we manage to model the excess inventory costs.
We create on each day:
- one arc from `morning` to `evening` without cost or capacity.
- one arc from `evening` to `free_night` with cost or capacity.
- one arc from `evening` to `morning` of next day with unit `excess_inventory_cost` and no capacity.
- one arc from `free_night` to `morning` of next day with capacity `maximum_inventory`.
"""
function add_depots_inventory_arcs_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
)
    D, T = instance.D, instance.T

    # Inventory depots
    for t = 1:T, d = 1:D
        n1 = FGN(t = t, d = d, str = "morning")
        n2 = FGN(t = t, d = d, str = "evening")
        add_edge!(fg, n1, n2)

        n1 = FGN(t = t, d = d, str = "evening")
        n2 = FGN(t = t, d = d, str = "free_night")
        add_edge!(fg, n1, n2)

        n1 = FGN(t = t, d = d, str = "evening")
        n2 = FGN(t = t + 1, d = d, str = "morning")
        add_edge!(fg, n1, n2)
        set_cost!(fg, ne(fg), instance.depots[d].excess_inventory_cost[commodity_index])

        n1 = FGN(t = t, d = d, str = "free_night")
        n2 = FGN(t = t + 1, d = d, str = "morning")
        add_edge!(fg, n1, n2)
        set_capa_max!(fg, ne(fg), instance.depots[d].maximum_inventory[commodity_index, t])
    end
end

"""
    add_customer_inventory_arcs_CFGC!(fg::FlowGraph;
                                        instance::Instance,
                                        customer_index::Int,
                                        commodity_index::Int,
    )

Add the arcs corresponding to the customer `customer_index` inventory dynamics.

Thanks to the `free_night` nodes we manage to model the excess inventory costs.
We create on each day:
- one arc from `morning` to `evening` without cost or capacity.
- one arc from `evening` to `free_night` with cost or capacity.
- one arc from `evening` to `morning` of next day with unit `excess_inventory_cost` and no capacity.
- one arc from `free_night` to `morning` of next day with capacity `maximum_inventory`.
"""
function add_customer_inventory_arcs_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    customer_index::Int,
    commodity_index::Int,
)
    D, T = instance.D, instance.T

    # Inventory customer
    for t = 1:T
        n1 = FGN(t = t, c = customer_index, str = "morning")
        n2 = FGN(t = t, c = customer_index, str = "evening")
        add_edge!(fg, n1, n2)


        n1 = FGN(t = t, c = customer_index, str = "evening")
        n2 = FGN(t = t, c = customer_index, str = "free_night")
        add_edge!(fg, n1, n2)

        n1 = FGN(t = t, c = customer_index, str = "evening")
        n2 = FGN(t = t + 1, c = customer_index, str = "morning")
        add_edge!(fg, n1, n2)
        set_cost!(
            fg,
            ne(fg),
            instance.customers[customer_index].excess_inventory_cost[commodity_index],
        )

        n1 = FGN(t = t, c = customer_index, str = "free_night")
        n2 = FGN(t = t + 1, c = customer_index, str = "morning")
        add_edge!(fg, n1, n2)
        set_capa_max!(
            fg,
            ne(fg),
            instance.customers[customer_index].maximum_inventory[commodity_index, t],
        )
    end
end

"""
    add_routes_arcs_CFGC!(fg::FlowGraph;
                            instance::Instance,
                            customer_index::Int,
                            commodity_index::Int, 
                            routes::Vector{Route},
                            dates::Vector,
                            costs::Vector,
                            force_values::Bool,
                            former_quantities_former_routes::Dict, 
                            former_quantities_new_routes::Array,
    )

Add the arcs corresponding to the `routes` paths.

Two types of routes are represented:
- new direct ones from depots to the customer with `customer_index`.
- old routes with each possible position of the customer for reinsertion.
    The (routing + other customers inventories and shortage) costs induced by 
    the reinsertion at each position are precomputed and stored in `costs`.
    The dates of arrival at each reinsertion position are also precomputed 
    and stored in `dates`.
We enable forcing the quantities to send through the routes with the boolean
`force_values` and quantities `former_quantities_former_routes` and 
`former_quantities_new_routes`. This is done to initialize the flow solution
with the value deduced from the current IRP `solution`, to speed-up computations.
This is done in [`one_step_ruin_recreate_customer!`](@ref).
"""
function add_routes_arcs_CFGC!(
    fg::FlowGraph;
    instance::Instance,
    customer_index::Int,
    commodity_index::Int, 
    routes::Vector{Route},
    dates::Vector,
    costs::Vector,
    force_values::Bool,
    former_quantities_former_routes::Dict, 
    former_quantities_new_routes::Array,
)
    D, T = instance.D, instance.T

    # Trip new routes
    for t = 1:T, d = 1:D
        n1 = FGN(t = t, d = d, str = "morning")
        arrival_date = t + floor(instance.transport_durations[d, D+customer_index] / instance.nb_transport_hours_per_day)
        if arrival_date <= T
            n2 = FGN(t = arrival_date, c = customer_index, str = "evening")
            add_edge!(fg, n1, n2)
            if force_values
                set_value!(fg, ne(fg), former_quantities_new_routes[commodity_index, d, t])
            end
        end
    end

    # Trip existing routes
    for (r, route) in enumerate(routes)
        n1 = FGN(t = route.t, d = route.d, str = "morning")
        n2 = FGN(t = route.t, str = "route_$r")
        add_edge!(fg, n1, n2)

        for i = 1:(get_nb_stops(route)+1) 
            if costs[r][i] != -1 
                n1 = FGN(t = route.t, str = "route_$r")
                n2 = FGN(t = dates[r][i], c = customer_index, s = i, str = "route_$r")
                add_edge!(fg, n1, n2)
                if force_values 
                    if haskey(former_quantities_former_routes, route.id) && former_quantities_former_routes[route.id][1] == i
                        set_value!(fg, ne(fg), former_quantities_former_routes[route.id][2][commodity_index])
                    else
                        set_capa_max!(fg, ne(fg), 0)
                    end
                end
                n3 = FGN(t = dates[r][i], c = customer_index, str = "evening")
                add_edge!(fg, n2, n3)
            end  
        end
    end
end

"""
    add_cycle_arcs_CFGC!(fg::FlowGraph)

Add the arcs between artificial nodes to create the circulation.
"""
function add_cycle_arcs_CFGC!(fg::FlowGraph)
    add_edge!(fg, FGN(str = "source"), FGN(str = "initial_inventory"))
    add_edge!(fg, FGN(str = "source"), FGN(str = "production"))
    add_edge!(fg, FGN(str = "source"), FGN(str = "shortage_compensation"))

    add_edge!(fg, FGN(str = "final_inventory"), FGN(str = "sink"))
    add_edge!(fg, FGN(str = "demand"), FGN(str = "sink"))
    add_edge!(fg, FGN(str = "delivery_other_customers"), FGN(str = "sink"))

    add_edge!(fg, FGN(str = "sink"), FGN(str = "source"))
end

"""
    commodity_flow_graph_customer(instance::Instance;
                                    customer_index::Int,
                                    commodity_index::Int,
                                    routes::Vector{Route},
                                    dates::Vector,
                                    costs::Vector,
                                    force_values::Bool = false,
                                    former_quantities_former_routes::Dict = Dict(), 
                                    former_quantities_new_routes::Array = zeros(1),
    )

Create the commodity flow graph corresponding to `commodity_index` for the reinsertion of 
the customer with index `customer_index`.

The (routing + other customers inventories and shortage) costs induced by 
the reinsertion at each position are precomputed and stored in `costs`.
The dates of arrival at each reinsertion position are also precomputed 
and stored in `dates`.
We enable forcing the quantities to send through the routes with the boolean
`force_values` and quantities `former_quantities_former_routes` and 
`former_quantities_new_routes`. This is done to initialize the flow solution
with the value deduced from the current IRP `solution`, to speed-up computations.
This is done in [`one_step_ruin_recreate_customer!`](@ref).
The flowgraph is based on the structure [`FlowGraph`](@ref).
"""
function commodity_flow_graph_customer(
    instance::Instance;
    customer_index::Int,
    commodity_index::Int,
    routes::Vector{Route},
    dates::Vector,
    costs::Vector,
    force_values::Bool = false,
    former_quantities_former_routes::Dict = Dict(), 
    former_quantities_new_routes::Array = zeros(1),
    )

    fg = FlowGraph()

    ## Nodes

    # Artificial nodes
    add_artificial_nodes_CFGC!(fg)
    # Nodes for each day
    add_every_day_nodes_CFGC!(
        fg,
        instance = instance,
        customer_index = customer_index,
        routes = routes,
        dates = dates, 
        costs = costs,
    )

    ## Arcs

    # Initial and final inventory depots and customer
    add_initial_final_inventory_arcs_CFGC!(
        fg,
        instance = instance,
        customer_index = customer_index,
        commodity_index = commodity_index,
    )
    # Production and delivery to other customers from depots
    add_production_delivery_arcs_depots_CFGC!(
        fg,
        instance = instance,
        commodity_index = commodity_index,
    )
    # Shortage and demand customer
    add_shortage_demand_arcs_customer_CFGC!(
        fg,
        instance = instance,
        customer_index = customer_index,
        commodity_index = commodity_index,
    )
    # Inventory depots
    add_depots_inventory_arcs_CFGC!(
        fg,
        instance = instance,
        commodity_index = commodity_index,
    )
    # Inventory customer
    add_customer_inventory_arcs_CFGC!(
        fg,
        instance = instance,
        customer_index = customer_index,
        commodity_index = commodity_index,
    )
    # Routes
    add_routes_arcs_CFGC!(
        fg,
        instance = instance,
        customer_index = customer_index,
        commodity_index = commodity_index,
        routes = routes,
        dates = dates,
        costs = costs,
        force_values = force_values,
        former_quantities_former_routes = former_quantities_former_routes, 
        former_quantities_new_routes = former_quantities_new_routes,
    )
    # Cycle
    add_cycle_arcs_CFGC!(fg)

    return fg
end
