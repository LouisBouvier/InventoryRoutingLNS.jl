## Time expanded vehicle graph
"""
    expanded_vehicle_flow_graph(instance::Instance; 
                                    add_new_routes_arcs::Bool = true,
                                    S_max::Int, 
                                    maxdist::Real = Inf,
                                    fixed_routes::Union{Nothing, Vector{Route}} = nothing,
                                    fixed_routes_costs::Union{Nothing, Vector{Int}} = nothing,
    )

Create a vehicles' flow graph with old fixed and new routes.

This function is called to derive the commodity reinsertion MILP
in [`commodity_insertion_MILP`](@ref) as well as the MILP to refill 
fixed routes in [`fill_fixed_routes_MILP`](@ref).

Two types of routes are represented:
- new direct ones from depots to customers, added when `add_new_routes_arcs` is `true`.
    When creating new routes, the argument `maxdist` may be used to sparsify the graph 
    by removing arcs with long distances. The maximum length of new routes is defined 
    by `S_max`, which is possibly distinct from the value of `instance.S_max`.
- old `fixed_routes` that visit several stops, with corresponding costs `fixed_routes_costs`.
"""
function expanded_vehicle_flow_graph(instance::Instance; 
                                    add_new_routes_arcs::Bool = true,
                                    S_max::Int, 
                                    maxdist::Real = Inf,
                                    fixed_routes::Union{Nothing, Vector{Route}} = nothing,
                                    fixed_routes_costs::Union{Nothing, Vector{Int}} = nothing,
    )

    ## Get dimensions
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    vehicle_capacity, km_cost, stop_cost, vehicle_cost = instance.vehicle_capacity,
    instance.km_cost,
    instance.stop_cost,
    instance.vehicle_cost
    dist = instance.dist

    fg = FlowGraph()
    ## In case we model new routes 
    if add_new_routes_arcs
        # Nodes
        add_vertex!(fg, FGN(str = "start"))
        for t = 1:T, d = 1:D
            add_vertex!(fg, FGN(t = t, d = d, str = "morning"))
        end

        for t = 1:T, c = 1:C, s = 1:S_max
            add_vertex!(fg, FGN(t = t, c = c, s = s, str = "noon"))
        end

        add_vertex!(fg, FGN(str = "end"))

        ## Arcs

        # Create vehicles
        for t = 1:T, d = 1:D
            n1 = FGN(str = "start")
            n2 = FGN(t = t, d = d, str = "morning")
            add_edge!(fg, n1, n2)
        end

        # Travel d=>c
        for t = 1:T, d = 1:D, c = 1:C
            n1 = FGN(t = t, d = d, str = "morning")
            arrival_date = t + floor(instance.transport_durations[d, D+c] / instance.nb_transport_hours_per_day)
            if arrival_date <= T
                n2 = FGN(t = arrival_date, c = c, s = 1, str = "noon")
                add_edge!(fg, n1, n2)
                set_cost!(fg, ne(fg), vehicle_cost + stop_cost + km_cost * dist[n1.d, D+n2.c])
            end
        end

        # Travel c1=>c2
        for t = 1:T, c1 = 1:C, c2 = 1:C, s = 1:S_max-1
            if dist[D+c1, D+c2] <= maxdist
                n1 = FGN(t = t, c = c1, s = s, str = "noon")
                n2 = FGN(t = t, c = c2, s = (s + 1), str = "noon")
                add_edge!(fg, n1, n2)
                set_cost!(fg, ne(fg), stop_cost + km_cost * dist[D+n1.c, D+n2.c])
            end
        end

        # Vehicle arrival
        for t = 1:T, c = 1:C, s = 1:S_max
            n1 = FGN(t = t, c = c, s = s, str = "noon")
            n2 = FGN(str = "end")
            add_edge!(fg, n1, n2)
        end
    end
    # In case we model fixed routes
    if !isnothing(fixed_routes)
        # Add nodes
        add_vertex!(fg, FGN(str = "start"))
        for (r, route) in enumerate(fixed_routes)
            add_vertex!(fg, FGN(t = route.t, d = route.d, str = "morning"))
            add_vertex!(fg, FGN(t = route.stops[1].t, c = route.stops[1].c, s = 1, str = "noon_route_$r"))
        end
        add_vertex!(fg, FGN(str = "end"))

        # Arcs 
        for (r, route) in enumerate(fixed_routes)
            # start to depot
            n1 = FGN(str = "start")
            n2 = FGN(t = route.t, d = route.d, str = "morning")
            add_edge!(fg, n1, n2)
            # depot to first stop 
            n1 = FGN(t = route.t, d = route.d, str = "morning")
            n2 = FGN(t = route.stops[1].t, c = route.stops[1].c, s = 1, str = "noon_route_$r")
            add_edge!(fg, n1, n2)
            set_capa_max!(fg, ne(fg), 1)
            set_cost!(fg, ne(fg), fixed_routes_costs[r])
            # first stop to the end (the rest is useless here)
            n1 = FGN(t = route.stops[1].t, c = route.stops[1].c, s = 1, str = "noon_route_$r")
            n2 = FGN(str = "end")
            add_edge!(fg, n1, n2)
        end
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
