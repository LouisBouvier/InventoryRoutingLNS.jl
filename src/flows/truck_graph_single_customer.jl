## Time expanded vehicle graph for one customer

"""
    expanded_vehicle_flow_graph_customer(instance::Instance;
                                            customer_index::Int,
                                            routes::Vector{Route},
                                            cost_per_route::Vector,
                                            dates::Vector,
    )

Create the vehicles' flow graph of a customer indexed by `customer_index`.

This function is called to derive the customer reinsertion MILP
in [`customer_insertion_flow`](@ref).

Two types of routes are represented:
- new direct ones from depots to the customer with `customer_index`.
- old `routes` with each possible position of the customer for reinsertion.
    The (routing + other customers inventories and shortage) costs induced by 
    the reinsertion at each position are precomputed and stored in `cost_per_route`.
    The dates of arrival at each reinsertion position are also precomputed 
    and stored in `dates`.
"""
function expanded_vehicle_flow_graph_customer(
    instance::Instance;
    customer_index::Int,
    routes::Vector{Route},
    cost_per_route::Vector,
    dates::Vector,
)
    D, T, M = instance.D, instance.T, instance.M
    vehicle_capacity, km_cost, stop_cost, vehicle_cost = instance.vehicle_capacity,
    instance.km_cost,
    instance.stop_cost,
    instance.vehicle_cost
    dist = instance.dist

    fg = FlowGraph()

    ## Nodes

    add_vertex!(fg, FGN(str = "start"))

    for t = 1:T, d = 1:D
        add_vertex!(fg, FGN(t = t, d = d, str = "morning"))
    end

    for (r, route) in enumerate(routes)
        add_vertex!(fg, FGN(t = route.t, str = "route_$r"))
        for i = 1:(get_nb_stops(route)+1)
            if cost_per_route[r][i] != -1
                add_vertex!(fg, FGN(t = dates[r][i], c = customer_index, s = i, str = "route_$r"))
            end
        end
    end

    for t = 1:T
        add_vertex!(fg, FGN(t = t, c = customer_index, str = "evening"))
    end

    add_vertex!(fg, FGN(str = "end"))

    ## Arcs

    # Create vehicles
    for t = 1:T, d = 1:D
        n1 = FGN(str = "start")
        n2 = FGN(t = t, d = d, str = "morning")
        add_edge!(fg, n1, n2)
    end

    # Travel d=>c: new direct routes
    for t = 1:T, d = 1:D
        n1 = FGN(t = t, d = d, str = "morning")
        arrival_date = t + floor(instance.transport_durations[d, D+customer_index] / instance.nb_transport_hours_per_day)
        if arrival_date <= T
            n2 = FGN(t = arrival_date, c = customer_index, str = "evening")
            add_edge!(fg, n1, n2)
            set_cost!(fg, ne(fg), vehicle_cost + stop_cost + km_cost * dist[n1.d, D+n2.c])
        end
    end

    # Travel d=>c: existing routes
    for (r, route) in enumerate(routes)
        # first go through the route
        n1 = FGN(t = route.t, d = route.d, str = "morning")
        n2 = FGN(t = route.t, str = "route_$r")
        add_edge!(fg, n1, n2)
        set_capa_max!(fg, ne(fg), 1)

        for i = 1:(get_nb_stops(route)+1)
            if cost_per_route[r][i] != -1       
                # Then spread over the insertion places  
                n1 = FGN(t = route.t, str = "route_$r")
                n2 = FGN(t = dates[r][i], c = customer_index, s = i, str = "route_$r")
                add_edge!(fg, n1, n2)
                set_cost!(fg, ne(fg), cost_per_route[r][i])
                # Arrive to the customer
                n3 = FGN(t = dates[r][i], c = customer_index, str = "evening")
                add_edge!(fg, n2, n3)
            end
        end
    end


    # Vehicles arrival
    for t = 1:T
        n1 = FGN(t = t, c = customer_index,  str = "evening")
        n2 = FGN(str = "end")
        add_edge!(fg, n1, n2)
    end

    # Cycle
    n1 = FGN(str = "start")
    n2 = FGN(str = "end")
    add_edge!(fg, n1, n2)

    n1 = FGN(str = "end")
    n2 = FGN(str = "start")
    add_edge!(fg, n1, n2)

    return fg
end
