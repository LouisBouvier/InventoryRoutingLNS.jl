"""
    add_artificial_nodes_CFG!(fg::FlowGraph; refill_neighborhood::Bool)

Add the artificial nodes to the commodity flow graph `fg`.

These artificial nodes are used to build a flow problem.
- The `source` and `sink` nodes enable a circulation.
- `production` is a way to model and force the value of depots release with capacitated arcs.
- `demand` does the same for the customers demand.
- `initial_inventory` enables to set the initial inventory at each depot and each customer.
- `shortage_compensation` is a way to model the shortage costs in the flow.
- `final_inventory` gathers the inventory at each site in the end of the horizon `T`.
- `other_received_quantities` and `other_sent_quantities` are only created 
    when the boolean `refill_neighborhood` is `true`. This is done when defining 
    a large neighborhood MILP with [`fill_fixed_routes_MILP`](@ref).
"""
function add_artificial_nodes_CFG!(fg::FlowGraph; refill_neighborhood::Bool)
    add_vertex!(fg, FGN(; str="source"))

    add_vertex!(fg, FGN(; str="production"))
    add_vertex!(fg, FGN(; str="initial_inventory"))
    add_vertex!(fg, FGN(; str="shortage_compensation"))
    if refill_neighborhood
        add_vertex!(fg, FGN(; str="other_received_quantities"))
    end

    add_vertex!(fg, FGN(; str="demand"))
    if refill_neighborhood
        add_vertex!(fg, FGN(; str="other_sent_quantities"))
    end
    add_vertex!(fg, FGN(; str="final_inventory"))

    return add_vertex!(fg, FGN(; str="sink"))
end

"""
    add_every_day_nodes_CFG!(fg::FlowGraph;
                                instance::Instance,
                                list_depots::AbstractVector{Int},
                                list_customers::AbstractVector{Int},
                                S_max::Int,
    )

Add the daily inventory nodes to the commodity flow graph.

We update `fg` with new nodes:
- One `morning` and `evening` node on each day `t` for each site.
    We remind that demand, release and routes departures occur in the morning,
    whereas routes arrival in the evening. 
- One `free_night` node on each day to incorporate the excess inventory costs.
- One `noon` node for each position in a new route for the customers.
    Most of the time `S_max` is `1`(in this function, not in `instance` data) and only one 
    position is considered: in this case we plan to build new direct routes.
"""
function add_every_day_nodes_CFG!(
    fg::FlowGraph;
    instance::Instance,
    list_depots::AbstractVector{Int},
    list_customers::AbstractVector{Int},
    S_max::Int,
)
    T = instance.T
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    # Nodes for each day
    for t in 1:T
        # Depots
        for d in list_depots
            add_vertex!(fg, FGN(; t=t, d=d, str="morning"))
            add_vertex!(fg, FGN(; t=t, d=d, str="evening"))
            add_vertex!(fg, FGN(; t=t, d=d, str="free_night"))
        end
        # Customers
        for c in list_customers
            add_vertex!(fg, FGN(; t=t, c=c, str="morning"))
            if S_max == 1
                add_vertex!(fg, FGN(; t=t, c=c, s=1, str="noon"))
            else
                for s in 1:S_max, t_h in 0:(nb_transport_hours_per_day - 1)
                    add_vertex!(fg, FGN(; t=t, t_h=t_h, c=c, s=s, str="noon"))
                end
            end
            add_vertex!(fg, FGN(; t=t, c=c, str="evening"))
            add_vertex!(fg, FGN(; t=t, c=c, str="free_night"))
        end
    end
    # Nodes of the last day
    for d in list_depots
        add_vertex!(fg, FGN(; t=T + 1, d=d, str="morning"))
    end
    for c in list_customers
        add_vertex!(fg, FGN(; t=T + 1, c=c, str="morning"))
    end
end

"""
    add_initial_final_inventory_arcs_CFG!(fg::FlowGraph;
                                            instance::Instance,
                                            commodity_index::Int,
                                            list_depots::AbstractVector{Int},
                                            list_customers::AbstractVector{Int},
    )

Add arcs between the artificial nodes and initial and final inventory nodes.

The arcs from `initial_inventory` to the morning of the first day are used to set
the initial inventories to the values stored in `instance`. 
The final inventories are aggregated for clarity and could be used to add final 
inventory costs for instance.
"""
function add_initial_final_inventory_arcs_CFG!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
    list_depots::AbstractVector{Int},
    list_customers::AbstractVector{Int},
)
    T = instance.T
    # Initial inventory depots
    for d in list_depots
        n1 = FGN(; str="initial_inventory")
        n2 = FGN(; t=1, d=d, str="morning")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.depots[d].initial_inventory[commodity_index])
    end
    # Initial inventory customers
    for c in list_customers
        n1 = FGN(; str="initial_inventory")
        n2 = FGN(; t=1, c=c, str="morning")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.customers[c].initial_inventory[commodity_index])
    end

    # Final inventory depots
    for d in list_depots
        n1 = FGN(; t=T + 1, d=d, str="morning")
        n2 = FGN(; str="final_inventory")
        add_edge!(fg, n1, n2)
    end
    # Final inventory customers
    for c in list_customers
        n1 = FGN(; t=T + 1, c=c, str="morning")
        n2 = FGN(; str="final_inventory")
        add_edge!(fg, n1, n2)
    end
end

"""
    add_production_arcs_depots_CFG!(fg::FlowGraph;
                                    instance::Instance,
                                    commodity_index::Int,
                                    list_depots::AbstractVector{Int},
                                    refill_neighborhood::Bool,
    )

Add the arcs corresponding to release and quantities to send to other customers.

We use the arcs from `production` to the morning of each day to set the release
of each customer in accordance with the data stored in `instance`.
Besides, since we possibly fix a part of the solution when `refill_neighborhood` is `true`, 
the arcs to `other_sent_quantities` nodes are used to take the 
other deliveries into account in the inventory dynamics of the depots.
"""
function add_production_arcs_depots_CFG!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
    list_depots::AbstractVector{Int},
    refill_neighborhood::Bool,
)
    T = instance.T
    # Production depots
    for t in 1:T, d in list_depots
        n1 = FGN(; str="production")
        n2 = FGN(; t=t, d=d, str="morning")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.depots[d].production[commodity_index, t])
    end
    # Other sent quantities if in large neighborhood
    if refill_neighborhood
        for t in 1:T, d in list_depots
            n1 = FGN(; t=t, d=d, str="morning")
            n2 = FGN(; str="other_sent_quantities")
            add_edge!(fg, n1, n2)
            set_value!(fg, ne(fg), instance.depots[d].quantity_sent[commodity_index, t])
        end
    end
end

"""
    add_shortage_demand_arcs_customer_CFG!(fg::FlowGraph;
                                            instance::Instance,
                                            commodity_index::Int,
                                            list_customers::AbstractVector{Int},
                                            refill_neighborhood::Bool,
    )   

Add the arcs corresponding to demand, shortage and quantities received.

As for the release, the arcs from each morning to the node `demand`
are used to fix the demand in accordance with the data of `instance`.
Besides, we create arcs from the node `shortage_compensation` to each morning 
node with shortage cost to model the soft minimum inventory constraint. 
Last, when `refill_neighborhood` is `true`, we also create arcs from `other_received_quantities`
to morning nodes to take the rest of the current solution into account.
"""
function add_shortage_demand_arcs_customer_CFG!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
    list_customers::AbstractVector{Int},
    refill_neighborhood::Bool,
)
    T = instance.T
    # Shortage customers
    for t in 1:T, c in list_customers
        n1 = FGN(; str="shortage_compensation")
        n2 = FGN(; t=t, c=c, str="morning")
        add_edge!(fg, n1, n2)
        set_cost!(fg, ne(fg), instance.customers[c].shortage_cost[commodity_index])
    end
    # Demand customers
    for t in 1:T, c in list_customers
        n1 = FGN(; t=t, c=c, str="morning")
        n2 = FGN(; str="demand")
        add_edge!(fg, n1, n2)
        set_value!(fg, ne(fg), instance.customers[c].demand[commodity_index, t])
    end
    # Other received quantities if in neighborhood
    if refill_neighborhood
        for t in 1:T, c in list_customers
            n1 = FGN(; str="other_received_quantities")
            n2 = FGN(; t=t, c=c, str="evening")
            add_edge!(fg, n1, n2)
            set_value!(
                fg, ne(fg), instance.customers[c].quantity_received[commodity_index, t]
            )
        end
    end
end

"""
    add_depots_inventory_arcs_CFG!(fg::FlowGraph;
                                    instance::Instance,
                                    commodity_index::Int,
                                    list_depots::AbstractVector{Int},
    )

Add the arcs corresponding to the depots inventory dynamics.

Thanks to the `free_night` nodes we manage to model the excess inventory costs.
We create on each day:
- one arc from `morning` to `evening` without cost or capacity.
- one arc from `evening` to `free_night` with cost or capacity.
- one arc from `evening` to `morning` of next day with unit `excess_inventory_cost` and no capacity.
- one arc from `free_night` to `morning` of next day with capacity `maximum_inventory`.
"""
function add_depots_inventory_arcs_CFG!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
    list_depots::AbstractVector{Int},
)
    T = instance.T
    for t in 1:T, d in list_depots
        n1 = FGN(; t=t, d=d, str="morning")
        n2 = FGN(; t=t, d=d, str="evening")
        add_edge!(fg, n1, n2)

        n1 = FGN(; t=t, d=d, str="evening")
        n2 = FGN(; t=t, d=d, str="free_night")
        add_edge!(fg, n1, n2)

        n1 = FGN(; t=t, d=d, str="evening")
        n2 = FGN(; t=t + 1, d=d, str="morning")
        add_edge!(fg, n1, n2)
        set_cost!(fg, ne(fg), instance.depots[d].excess_inventory_cost[commodity_index])

        n1 = FGN(; t=t, d=d, str="free_night")
        n2 = FGN(; t=t + 1, d=d, str="morning")
        add_edge!(fg, n1, n2)
        set_capa_max!(fg, ne(fg), instance.depots[d].maximum_inventory[commodity_index, t])
    end
end

"""
    add_customer_inventory_arcs_CFG!(fg::FlowGraph;
                                        instance::Instance,
                                        commodity_index::Int,
                                        list_customers::AbstractVector{Int},
                                        S_max::Int,
    )

Add the arcs corresponding to the customers inventory dynamics.

Thanks to the `free_night` nodes we manage to model the excess inventory costs.
We create on each day:
- one arc from `morning` to `evening` without cost or capacity.
- one arc from `evening` to `free_night` with cost or capacity.
- one arc from `evening` to `morning` of next day with unit `excess_inventory_cost` and no capacity.
- one arc from `free_night` to `morning` of next day with capacity `maximum_inventory`.
- one arc from each `noon` node to `evening` to connect the possible positions in new 
    routes with the inventory dynamics.
"""
function add_customer_inventory_arcs_CFG!(
    fg::FlowGraph;
    instance::Instance,
    commodity_index::Int,
    list_customers::AbstractVector{Int},
    S_max::Int,
)
    T = instance.T
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day

    for t in 1:T, c in list_customers
        n1 = FGN(; t=t, c=c, str="morning")
        n2 = FGN(; t=t, c=c, str="evening")
        add_edge!(fg, n1, n2)

        if S_max == 1
            n1 = FGN(; t=t, c=c, s=1, str="noon")
            n2 = FGN(; t=t, c=c, str="evening")
            add_edge!(fg, n1, n2)
        else
            for s in 1:S_max, t_h in 0:(nb_transport_hours_per_day - 1)
                n1 = FGN(; t=t, t_h=t_h, c=c, s=s, str="noon")
                n2 = FGN(; t=t, c=c, str="evening")
                add_edge!(fg, n1, n2)
            end
        end

        n1 = FGN(; t=t, c=c, str="evening")
        n2 = FGN(; t=t, c=c, str="free_night")
        add_edge!(fg, n1, n2)

        n1 = FGN(; t=t, c=c, str="evening")
        n2 = FGN(; t=t + 1, c=c, str="morning")
        add_edge!(fg, n1, n2)
        set_cost!(fg, ne(fg), instance.customers[c].excess_inventory_cost[commodity_index])

        n1 = FGN(; t=t, c=c, str="free_night")
        n2 = FGN(; t=t + 1, c=c, str="morning")
        add_edge!(fg, n1, n2)
        set_capa_max!(
            fg, ne(fg), instance.customers[c].maximum_inventory[commodity_index, t]
        )
    end
end

"""
    add_new_routes_arcs_CFG!(fg::FlowGraph;
                                instance::Instance,
                                list_depots::AbstractVector{Int},
                                list_customers::AbstractVector{Int},
                                commodity_index::Int,
                                maxdist::Real,
                                relaxed_trip_cost::Bool,
                                average_content_sizes::Union{Nothing,AverageContentSizes},
                                S_max::Int,
                                force_routes_values::Bool,
                                sent_quantities_to_force::Array,
                                set_upper_capa::Bool,
                                possible_delays::Dict,
                                add_delayed_arcs::Bool,
    )

Add the arcs corresponding to new routes.

The `maxdist` argument is used to sparsify the graph, removing arcs corresponding
to long distances. 

When the boolean `relaxed_trip_cost` is `true`, we add costs on 
the routing arcs of the commodity flow graphs. This is done in a heurisic 
way in [`initialization_plus_ls!`](@ref) with vehicle fraction costs, and based on 
the statistics (saved in `average_content_sizes`) of a first solution 
in a second pass in [`modified_capa_initialization_plus_ls!`](@ref).
When used in [`one_step_ruin_recreate_commodity!`](@ref) or [`fill_fixed_routes_MILP`](@ref), 
no cost is set on those routing arcs of the commodity flow graphs.

We enable forcing the quantities to send through the routes with the boolean
`force_routes_values` and quantities `sent_quantities_to_force`. 
This is done to initialize the flow solution with the value deduced from 
the current IRP `solution`, to speed-up computations.
This is done in [`one_step_ruin_recreate_commodity!`](@ref).

For some applications in Machine Learning, we need to define a flow 
on a polytope (bounded) and thus to derive some upper capacities 
on the routing arcs. This is done when `set_upper_capa` is `true`.

Last, to derive a flow relaxation of the IRP, we need to add 
delayed arcs in the commodity flow graphs, which is done when 
`add_delayed_arcs` is `true`. In this case the direct delayed arcs 
have precomputed delays saved in `possible_delays`. The implementation
of the relaxation is done in [`lower_bound`](@ref). 
"""
function add_new_routes_arcs_CFG!(
    fg::FlowGraph;
    instance::Instance,
    list_depots::AbstractVector{Int},
    list_customers::AbstractVector{Int},
    commodity_index::Int,
    maxdist::Real,
    relaxed_trip_cost::Bool,
    average_content_sizes::Union{Nothing,AverageContentSizes},
    S_max::Int,
    force_routes_values::Bool,
    sent_quantities_to_force::Array,
    set_upper_capa::Bool,
    possible_delays::Dict,
    add_delayed_arcs::Bool,
)
    M, T, D = instance.M, instance.T, instance.D
    vehicle_cost = instance.vehicle_cost
    vehicle_capacity = instance.vehicle_capacity
    stop_cost = instance.stop_cost
    km_cost = instance.km_cost
    dist = instance.dist
    transport_durations = instance.transport_durations
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    l = [instance.commodities[m].l for m in 1:M]

    ## first case: only direct routes
    if S_max == 1
        # Trip
        for t in 1:T
            # d=>c
            for d in list_depots, c in list_customers
                if add_delayed_arcs
                    delayed_days = possible_delays[d][c]
                else
                    delayed_days = [
                        floor(transport_durations[d, D + c] / nb_transport_hours_per_day)
                    ]
                end
                for delay in delayed_days
                    arrival_day = t + delay
                    if arrival_day <= T
                        n1 = FGN(; t=t, d=d, str="morning")
                        n2 = FGN(; t=arrival_day, c=c, s=1, str="noon")
                        add_edge!(fg, n1, n2)
                        if set_upper_capa
                            depot = instance.depots[d]
                            capa_max_dc =
                                sum(depot.production[commodity_index, 1:t]) +
                                depot.initial_inventory[commodity_index]
                            set_capa_max!(fg, ne(fg), capa_max_dc)
                        end
                        if relaxed_trip_cost
                            if average_content_sizes !== nothing
                                capacity =
                                    (
                                        average_content_sizes.avg_l_d[d] +
                                        average_content_sizes.avg_l_c[c] +
                                        average_content_sizes.avg_l_t[t]
                                    ) / 3
                            else
                                capacity = vehicle_capacity
                            end
                            set_cost!(
                                fg,
                                ne(fg),
                                (
                                    vehicle_cost +
                                    stop_cost +
                                    km_cost * dist[n1.d, D + n2.c]
                                ) * l[commodity_index] / capacity,
                            )
                            if force_routes_values
                                set_value!(
                                    fg,
                                    ne(fg),
                                    sent_quantities_to_force[commodity_index, d, c, t],
                                )
                            end
                        end
                    end
                end
            end
        end
        ## second case: consider a succession of customers, need to take hours into account
    else
        # Trip
        for t in 1:T
            # d=>c
            for d in list_depots, c in list_customers
                transport_hours = transport_durations[d, D + c]
                delta_days = floor(transport_hours / nb_transport_hours_per_day)
                arrival_day = t + delta_days
                arrival_hour = transport_hours - nb_transport_hours_per_day * delta_days
                if arrival_day <= T
                    n1 = FGN(; t=t, d=d, str="morning")
                    n2 = FGN(; t=arrival_day, t_h=arrival_hour, c=c, s=1, str="noon")
                    add_edge!(fg, n1, n2)
                    if set_upper_capa
                        depot = instance.depots[d]
                        capa_max_dc =
                            sum(depot.production[commodity_index, 1:t]) +
                            depot.initial_inventory[commodity_index]
                        set_capa_max!(fg, ne(fg), capa_max_dc)
                    end
                    if relaxed_trip_cost
                        if average_content_sizes !== nothing
                            capacity =
                                (
                                    average_content_sizes.avg_l_d[d] +
                                    average_content_sizes.avg_l_c[c] +
                                    average_content_sizes.avg_l_t[t]
                                ) / 3
                        else
                            capacity = vehicle_capacity
                        end
                        set_cost!(
                            fg,
                            ne(fg),
                            (vehicle_cost + stop_cost + km_cost * dist[n1.d, D + n2.c]) *
                            l[commodity_index] / capacity,
                        )
                        if force_routes_values
                            set_value!(
                                fg,
                                ne(fg),
                                sent_quantities_to_force[commodity_index, d, c, t],
                            )
                        end
                    end
                end
            end
            # c1=>c2
            for s in 1:(S_max - 1),
                c1 in list_customers,
                c2 in list_customers,
                departure_hour in 0:(nb_transport_hours_per_day - 1)

                n1 = FGN(; t=t, t_h=departure_hour, c=c1, s=s, str="noon")
                vertex_index_n1 = get_vertexindex(fg, n1)
                inneighbors_n1 = Graphs.inneighbors(fg, vertex_index_n1)
                if dist[D + c1, D + c2] <= maxdist && length(inneighbors_n1) > 0
                    ## not exactly the relaxation here
                    transport_hours = transport_durations[D + c1, D + c2]
                    delta_days = floor(
                        (transport_hours + departure_hour) / nb_transport_hours_per_day
                    )
                    arrival_day = t + delta_days
                    arrival_hour =
                        (departure_hour + transport_hours) -
                        nb_transport_hours_per_day * delta_days
                    if arrival_day <= T
                        n2 = FGN(;
                            t=arrival_day, t_h=arrival_hour, c=c2, s=(s + 1), str="noon"
                        )
                        add_edge!(fg, n1, n2)
                        if relaxed_trip_cost
                            if average_content_sizes !== nothing
                                capacity =
                                    (
                                        average_content_sizes.avg_l_c[c1] +
                                        average_content_sizes.avg_l_c[c2] +
                                        average_content_sizes.avg_l_t[t]
                                    ) / 3
                            else
                                capacity = vehicle_capacity
                            end
                            set_cost!(
                                fg,
                                ne(fg),
                                (stop_cost + km_cost * dist[D + c1, D + c2]) *
                                l[commodity_index] / capacity,
                            )
                        end
                    end
                end
            end
        end
    end
end

"""
    add_fixed_routes_arcs_CFG!(fg::FlowGraph;
                                instance::Instance,
                                fixed_routes::Vector{Route},
                                commodity_index::Int,
                                force_routes_values::Bool,
    )

Add the arcs corresponding to the `fixed_routes` paths.

This function is used to integrate some routes with pre-defined 
paths in the flow solution. We add the nodes and arcs corresponding 
to those paths, and connect them to the starting depots and to the 
evening of the customers visited. 
It is particularly useful in [`fill_fixed_routes_MILP`](@ref).
"""
function add_fixed_routes_arcs_CFG!(
    fg::FlowGraph;
    instance::Instance,
    fixed_routes::Vector{Route},
    commodity_index::Int,
    force_routes_values::Bool,
)
    ## Get dimensions
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    vehicle_capacity = instance.vehicle_capacity
    l = [instance.commodities[m].l for m in 1:M]
    concerned_depots = select_relevant_depots(instance, commodity_index)
    concerned_customers = select_relevant_customers(instance, commodity_index)

    ## Browse fixed routes
    @showprogress "Add fixed routes arcs " for (r, route) in enumerate(fixed_routes)
        t = route.t
        d = route.d

        # add nodes
        for (s, stop) in enumerate(route.stops)
            arrival_date = stop.t
            c = stop.c
            add_vertex!(fg, FGN(; t=arrival_date, c=c, s=s, str="noon_route_$r"))
        end

        # add arcs
        # d => c
        n1 = FGN(; t=t, d=d, str="morning")
        n2 = FGN(; t=route.stops[1].t, c=route.stops[1].c, s=1, str="noon_route_$r")
        add_edge!(fg, n1, n2)

        # in case the depot is not concerned by the commodity
        if concerned_depots[route.d] != 1
            set_value!(fg, ne(fg), 0)
        end

        # c1 => c2
        for s in 1:(length(route.stops) - 1)
            n1 = FGN(; t=route.stops[s].t, c=route.stops[s].c, s=s, str="noon_route_$r")
            n2 = FGN(;
                t=route.stops[s + 1].t,
                c=route.stops[s + 1].c,
                s=(s + 1),
                str="noon_route_$r",
            )
            add_edge!(fg, n1, n2)
        end

        # c_noon => c_evening
        for s in 1:length(route.stops)
            n1 = FGN(; t=route.stops[s].t, c=route.stops[s].c, s=s, str="noon_route_$r")
            n2 = FGN(; t=route.stops[s].t, c=route.stops[s].c, str="evening")
            add_edge!(fg, n1, n2)
            if concerned_customers[route.stops[s].c] == 0
                set_value!(fg, ne(fg), 0)
            end
            if force_routes_values
                set_value!(fg, ne(fg), route.stops[s].Q[commodity_index])
            end
        end
    end
end

"""
    add_cycle_arcs_CFG!(fg::FlowGraph, refill_neighborhood::Bool)

Add the arcs between artificial nodes to create the circulation.
"""
function add_cycle_arcs_CFG!(fg::FlowGraph, refill_neighborhood::Bool)
    add_edge!(fg, FGN(; str="source"), FGN(; str="initial_inventory"))
    add_edge!(fg, FGN(; str="source"), FGN(; str="production"))
    add_edge!(fg, FGN(; str="source"), FGN(; str="shortage_compensation"))
    if refill_neighborhood
        add_edge!(fg, FGN(; str="source"), FGN(; str="other_received_quantities"))
    end

    add_edge!(fg, FGN(; str="final_inventory"), FGN(; str="sink"))
    add_edge!(fg, FGN(; str="demand"), FGN(; str="sink"))
    if refill_neighborhood
        add_edge!(fg, FGN(; str="other_sent_quantities"), FGN(; str="sink"))
    end

    return add_edge!(fg, FGN(; str="sink"), FGN(; str="source"))
end

"""
    commodity_flow_graph(instance::Instance;
                            commodity_index::Int,
                            add_new_routes_arcs::Bool = true,
                            S_max::Int = 1,
                            maxdist::Real = Inf,
                            relaxed_trip_cost::Bool = true,
                            average_content_sizes::Union{Nothing,AverageContentSizes} = nothing,
                            force_routes_values::Bool = false,
                            sent_quantities_to_force::Array = zeros(1),
                            sparsify::Bool = true,
                            set_upper_capa::Bool = false,
                            possible_delays::Dict = Dict(),
                            add_delayed_arcs::Bool = false,
                            fixed_routes::Union{Nothing, Vector{Route}} = nothing,
                            refill_neighborhood::Bool = false,
    )

Create the commodity flow graph corresponding to `commodity_index`.
 
When `add_new_routes_arcs` is `true`, we add the arcs corresponding to new 
routes with [`add_new_routes_arcs_CFG!`](@ref).

The argument `S_max` is used to restrict the length of the new routes to create.
It is currently systematically set to `1`. See [`initialization_plus_ls!`](@ref) and 
[`one_step_ruin_recreate_commodity!`](@ref) for instance. 

The `maxdist` argument is used to sparsify the graph, removing arcs corresponding
to long distances.

When `sparsify` is `true`, we restrict the nodes to the customers and depots that
are concerned by the commodity with index `commodity_index`. We emphasize in this 
case the indices of the nodes and arcs differ from one commodity flow graph to 
the other, which makes it difficult to combine them for instance in 
[`fill_fixed_routes_MILP`](@ref). We may thus disable this sparsification 
and force zero values in this case. 

When the boolean `relaxed_trip_cost` is `true`, we add costs on 
the routing arcs of the commodity flow graphs. This is done in a heurisic 
way in [`initialization_plus_ls!`](@ref) with vehicle fraction costs, and based on 
the statistics (saved in `average_content_sizes`) of a first solution 
in a second pass in [`modified_capa_initialization_plus_ls!`](@ref).
When used in [`one_step_ruin_recreate_commodity!`](@ref) or [`fill_fixed_routes_MILP`](@ref), 
no cost is set on those routing arcs of the commodity flow graphs.

We enable forcing the quantities to send through the routes with the boolean
`force_routes_values` and quantities `sent_quantities_to_force`. 
This is done to initialize the flow solution with the value deduced from 
the current IRP `solution`, to speed-up computations.
This is done in [`one_step_ruin_recreate_commodity!`](@ref).

For some applications in Machine Learning, we need to define a flow 
on a polytope (bounded) and thus to derive some upper capacities 
on the routing arcs. This is done when `set_upper_capa` is `true`.

To derive a flow relaxation of the IRP, we need to add 
delayed arcs in the commodity flow graphs, which is done when 
`add_delayed_arcs` is `true`. In this case the direct delayed arcs 
have precomputed delays saved in `possible_delays`. The implementation
of the relaxation is done in [`lower_bound`](@ref). 

Last, as stated before, this graph structure can be used and combined 
in the [`fill_fixed_routes_MILP`](@ref) function, possibly to derive 
a large neighborhood when the boolean `refill_neighborhood` is `true`.
In this case we provide the `fixed_routes` to add in [`add_fixed_routes_arcs_CFG!`](@ref).
"""
function commodity_flow_graph(
    instance::Instance;
    commodity_index::Int,
    add_new_routes_arcs::Bool=true,
    S_max::Int=1,
    maxdist::Real=Inf,
    relaxed_trip_cost::Bool=true,
    average_content_sizes::Union{Nothing,AverageContentSizes}=nothing,
    force_routes_values::Bool=false,
    sent_quantities_to_force::Array=zeros(1),
    sparsify::Bool=true,
    set_upper_capa::Bool=false,
    possible_delays::Dict=Dict(),
    add_delayed_arcs::Bool=false,
    fixed_routes::Union{Nothing,Vector{Route}}=nothing,
    refill_neighborhood::Bool=false,
)
    D, C = instance.D, instance.C

    if S_max == 1 && sparsify && add_new_routes_arcs
        concerned_depots = select_relevant_depots(instance, commodity_index)
        list_depots = [d for d in 1:D if concerned_depots[d] == 1]
        concerned_customers = select_relevant_customers(instance, commodity_index)
        list_customers = [c for c in 1:C if concerned_customers[c] == 1]

    elseif !isnothing(fixed_routes) && sparsify
        list_depots = unique([route.d for route in fixed_routes])
        list_customers = Vector{Int}()
        for route in fixed_routes
            for stop in route.stops
                append!(list_customers, stop.c)
            end
        end
        list_customers = unique(list_customers)

    else
        list_depots = 1:D
        list_customers = 1:C
    end

    fg = FlowGraph()

    ## Nodes

    # Artificial nodes
    add_artificial_nodes_CFG!(fg; refill_neighborhood=refill_neighborhood)
    # Nodes for each day
    add_every_day_nodes_CFG!(
        fg;
        instance=instance,
        list_depots=list_depots,
        list_customers=list_customers,
        S_max=S_max,
    )

    ## Arcs

    # Initial and final inventory
    add_initial_final_inventory_arcs_CFG!(
        fg;
        instance=instance,
        commodity_index=commodity_index,
        list_depots=list_depots,
        list_customers=list_customers,
    )
    # Production depots
    add_production_arcs_depots_CFG!(
        fg;
        instance=instance,
        commodity_index=commodity_index,
        list_depots=list_depots,
        refill_neighborhood=refill_neighborhood,
    )
    # Shortage and demand customers
    add_shortage_demand_arcs_customer_CFG!(
        fg;
        instance=instance,
        commodity_index=commodity_index,
        list_customers=list_customers,
        refill_neighborhood=refill_neighborhood,
    )
    # Inventory depots
    add_depots_inventory_arcs_CFG!(
        fg; instance=instance, commodity_index=commodity_index, list_depots=list_depots
    )
    # Inventory customers
    add_customer_inventory_arcs_CFG!(
        fg;
        instance=instance,
        commodity_index=commodity_index,
        list_customers=list_customers,
        S_max=S_max,
    )
    # Trips
    if add_new_routes_arcs
        add_new_routes_arcs_CFG!(
            fg;
            instance=instance,
            list_depots=list_depots,
            list_customers=list_customers,
            commodity_index=commodity_index,
            relaxed_trip_cost=relaxed_trip_cost,
            maxdist=maxdist,
            average_content_sizes=average_content_sizes,
            S_max=S_max,
            force_routes_values=force_routes_values,
            sent_quantities_to_force=sent_quantities_to_force,
            set_upper_capa=set_upper_capa,
            possible_delays=possible_delays,
            add_delayed_arcs=add_delayed_arcs,
        )
    end
    if !isnothing(fixed_routes)
        add_fixed_routes_arcs_CFG!(
            fg;
            instance=instance,
            fixed_routes=fixed_routes,
            commodity_index=commodity_index,
            force_routes_values=force_routes_values,
        )
    end
    # Cycle
    add_cycle_arcs_CFG!(fg, refill_neighborhood)

    return fg
end
