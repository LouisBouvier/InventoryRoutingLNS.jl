"""
    remove_customer!(instance::Instance, c::Int)

Remove the customer indexed by `c` from the routes of the solution.
"""
function remove_customer!(instance::Instance, c::Int)
    M, D, T = instance.M, instance.D, instance.T
    routes = list_routes(instance.solution)
    ## Save the former configuration 
    former_quantities_former_routes = Dict()
    former_quantities_new_routes = zeros(Int, M, D, T)
    ## Remove from the routes
    for route in routes
        # optimize_route!(route, instance)
        for (s, stop) in enumerate(route.stops)
            if stop.c == c
                route_copy = mycopy(route)
                deleteat!(route_copy.stops, s)
                if isempty(route_copy.stops)
                    former_quantities_new_routes[:, route.d, route.t] += stop.Q
                    update_instance_some_routes!(instance, [route], "delete")
                else
                    update_route_order!(
                        route_copy, instance, collect(1:get_nb_stops(route_copy))
                    )
                    update_instance_some_routes!(instance, [route], "delete")
                    update_instance_some_routes!(instance, [route_copy], "add")
                    former_quantities_former_routes[route_copy.id] = (s, stop.Q)
                end
                continue
            end
        end
    end
    return former_quantities_former_routes, former_quantities_new_routes
end

"""
    location_and_cost_insertion!(instance::Instance, c::Int, routes::Vector{Route})

Compute the costs, dates and capacities corresponding to the insertion places of customer `c` in `routes`.

For each route we compute and save the remaining loading capacity in `places`, 
the cost induced by the reinsertion of customer `c` (other customers' inventory
and shortage costs induced by delays, and routing costs) at each position in 
`costs`, and the dates of arrival to the corresponding reinsertion positions 
in `dates`. This information is used to build both the commodities and vehicles 
flow graphs, see [`commodity_flow_graph_customer`](@ref) and [`expanded_vehicle_flow_graph_customer`](@ref).
"""
function location_and_cost_insertion!(instance::Instance, c::Int, routes::Vector{Route})
    costs = []
    dates = []
    places = Vector{Float64}(undef, length(routes))
    to_delete = []
    for (r, route) in enumerate(routes)
        nb_stops = get_nb_stops(route)
        if nb_stops == instance.S_max
            append!(to_delete, r)
        else
            content = content_size(route, instance)
            T, M = instance.T, instance.M
            cs = unique_stops(route)
            ts = collect((route.t):T)
            ms = [m for m in 1:M if uses_commodity(route, m)]
            # compute the cost without the new customer (customers' inventory and routing)
            oldcost = compute_cost(
                instance;
                ds=Vector{Int}(),
                cs=cs,
                ms=ms,
                ts=ts,
                solution=SimpleSolution([route]),
            )
            costs_r = -ones(nb_stops + 1)
            dates_r = ones(nb_stops + 1)
            for i in (1:(nb_stops + 1))
                newroute = mycopy(route)
                insert!(newroute.stops, i, RouteStop(; c=c, t=route.t, Q=zeros(M)))
                update_route_order!(newroute, instance, collect(1:get_nb_stops(newroute)))
                if newroute.stops[end].t > T
                    continue
                end
                date_arrival = newroute.stops[i].t
                # compute the cost with the new customer at position i (customers' inventory and routing)
                update_instance_some_routes!(instance, [route], "delete", false)
                update_instance_some_routes!(instance, [newroute], "add", false)
                newcost = compute_cost(
                    instance;
                    ds=Vector{Int}(),
                    cs=cs,
                    ms=ms,
                    ts=ts,
                    solution=SimpleSolution([newroute]),
                )
                update_instance_some_routes!(instance, [newroute], "delete", false)
                update_instance_some_routes!(instance, [route], "add", false)
                # deduce the cost of adding customer c at place i of route r and corresponding arrival date 
                costs_r[i] = newcost - oldcost
                dates_r[i] = date_arrival
            end
            if all(costs_r .== -1)
                append!(to_delete, r)
            else
                places[r] = instance.vehicle_capacity - content
                append!(costs, [costs_r])
                append!(dates, [dates_r])
            end
        end
    end
    deleteat!(routes, to_delete)
    deleteat!(places, to_delete)
    return costs, dates, places, routes
end

"""
    coupling_constraint_customer_flow_insertion!(model::JuMP.Model,
                                                    instance::Instance,
                                                    customer_index::Int,
                                                    indices_m::Vector{Any},
                                                    nb_m::Int,
                                                    fgs_commodities::Vector{FlowGraph},
                                                    fg_vehicles::FlowGraph,
                                                    old_possible_routes::Vector{Route},
                                                    places::Vector{Float64},
                                                    costs::Vector,
                                                    dates::Vector,
    )

Add the constraints binding commodities and vehicles variables related to the reinsertion of customer `customer_index`.

Those bindings occur for two types of routes:
- new direct routes (relaxation of the capacity constraints per vehicle at the arc level).
- old routes in the solution (exact constraints given the pre-computed data).

In both cases we focus on a subset of `nb_m` commodities indexed by `indices_m` 
"""
function coupling_constraint_customer_flow_insertion!(
    model::JuMP.Model,
    instance::Instance,
    customer_index::Int,
    indices_m::Vector{Any},
    nb_m::Int,
    fgs_commodities::Vector{FlowGraph},
    fg_vehicles::FlowGraph,
    old_possible_routes::Vector{Route},
    places::Vector{Float64},
    costs::Vector,
    dates::Vector,
)
    D, T, M = instance.D, instance.T, instance.M
    vehicle_capacity = instance.vehicle_capacity
    l = [instance.commodities[m].l for m in 1:M]
    # Coupling vehicles and commodities

    # Trip d => c new routes
    @showprogress "Link trips d=>c new routes" for d in 1:D, t in 1:T
        n1 = FGN(; t=t, d=d, str="morning")
        arrival_date =
            t + floor(
                instance.transport_durations[d, D + customer_index] /
                instance.nb_transport_hours_per_day,
            )
        if arrival_date <= T
            n2 = FGN(; t=arrival_date, c=customer_index, str="evening")
            edge12m = get_edgeindex(fgs_commodities[1], n1, n2)
            edge12veh = get_edgeindex(fg_vehicles, n1, n2)
            @constraint(
                model,
                sum(model[:z][i_m, edge12m] * l[indices_m[i_m]] for i_m in 1:nb_m) <=
                    model[:x][edge12veh] * vehicle_capacity
            )
        end
    end
    # Trip d => c former routes
    @showprogress "Link trips d=>c former routes" for (r, route) in
                                                      enumerate(old_possible_routes)
        for i in 1:(get_nb_stops(route) + 1)
            if costs[r][i] != -1
                n1 = FGN(; t=route.t, str="route_$r")
                n2 = FGN(; t=dates[r][i], c=customer_index, s=i, str="route_$r")
                edge12m = get_edgeindex(fgs_commodities[1], n1, n2)
                edge12veh = get_edgeindex(fg_vehicles, n1, n2)
                @constraint(
                    model,
                    sum(model[:z][i_m, edge12m] * l[indices_m[i_m]] for i_m in 1:nb_m) <=
                        model[:x][edge12veh] * places[r]
                )
            end
        end
    end
end

"""
    build_model_objective_customer_insertion_flow!(model::JuMP.Model,
                                                    fg_vehicles::FlowGraph,
                                                    fgs_commodities::Vector{FlowGraph},
                                                    nb_m::Int,
    )

Define the objective function of the customer insertion MILP based on vehicles' and commodities' flow variables.

This cost is the sum of:
- one vehicles' flow cost given the arcs' costs of the `fg_vehicles` graph.
- one commodity cost per commodity given `fgs_commodities` arcs costs.
"""
function build_model_objective_customer_insertion_flow!(
    model::JuMP.Model, fg_vehicles::FlowGraph, fgs_commodities::Vector{FlowGraph}, nb_m::Int
)
    # objective function
    obj = AffExpr(0.0)
    add_flow_cost!(obj, model[:x], fg_vehicles)
    @showprogress "Commodities objective function" for i_m in 1:nb_m
        add_flow_cost!(obj, model[:z][i_m, :], fgs_commodities[i_m])
    end
    @objective(model, Min, obj)
end

"""
    customer_insertion_flow(instance::Instance;
                            optimizer,
                            customer_index::Int,
                            old_possible_routes::Vector{Route},
                            costs::Vector,
                            places::Vector,
                            dates::Vector,
                            former_quantities_former_routes::Dict, 
                            former_quantities_new_routes::Array,
                            use_warm_start::Bool,
                            force_values::Bool,
                            values_vehicles_flow::Array,
                            values_commodities_flows::Array,
    )

Define and solve the customer insertion MILP for the customer indexed by `customer_index`.

We possibly force the values on former and new routes using `force_values` 
boolean and `former_quantities_former_routes` and `former_quantities_new_routes` 
information, see [`commodity_flow_graph_customer`](@ref).

We can use a warmstart if `use_warm_start` is `true`, with the values of the flows set 
to `values_commodities_flows` and `values_vehicles_flow`.
"""
function customer_insertion_flow(
    instance::Instance;
    optimizer,
    customer_index::Int,
    old_possible_routes::Vector{Route},
    costs::Vector,
    places::Vector,
    dates::Vector,
    former_quantities_former_routes::Dict,
    former_quantities_new_routes::Array,
    use_warm_start::Bool,
    force_values::Bool,
    values_vehicles_flow::Array,
    values_commodities_flows::Array,
)
    M = instance.M
    model = Model(optimizer)

    ## Vehicles flow
    fg_vehicles = expanded_vehicle_flow_graph_customer(
        instance;
        customer_index=customer_index,
        routes=old_possible_routes,
        cost_per_route=costs,
        dates=dates,
    )

    @variable(model, x[1:ne(fg_vehicles)] >= 0, integer = true)
    if use_warm_start
        set_start_value.(x, values_vehicles_flow)
    end
    add_flow_constraints!(model, model[:x], fg_vehicles)

    ## Commodities flow
    commodities_of_c = commodities_used_customer(instance, customer_index)
    nb_m = sum(Int.(commodities_of_c))

    fgs_commodities = Vector{FlowGraph}(undef, nb_m)
    fg_commodity_ref = commodity_flow_graph_customer(
        instance;
        customer_index=customer_index,
        commodity_index=1,
        routes=old_possible_routes,
        dates=dates,
        costs=costs,
    )
    @variable(model, z[1:nb_m, 1:ne(fg_commodity_ref)] >= 0, integer = true)
    if use_warm_start
        set_start_value.(z, values_commodities_flows)
    end
    count_m = 0
    indices_m = []
    @showprogress "Commodity flow graph " for m in 1:M
        if commodities_of_c[m]
            count_m += 1
            fgs_commodities[count_m] = commodity_flow_graph_customer(
                instance;
                customer_index=customer_index,
                commodity_index=m,
                routes=old_possible_routes,
                dates=dates,
                costs=costs,
                force_values=force_values,
                former_quantities_former_routes=former_quantities_former_routes,
                former_quantities_new_routes=former_quantities_new_routes,
            )
            add_flow_constraints!(model, model[:z][count_m, :], fgs_commodities[count_m])
            push!(indices_m, m)
        end
    end

    ## Coupling vehicles and commodities

    coupling_constraint_customer_flow_insertion!(
        model,
        instance,
        customer_index,
        indices_m,
        nb_m,
        fgs_commodities,
        fg_vehicles,
        old_possible_routes,
        places,
        costs,
        dates,
    )

    ## Create objective function

    build_model_objective_customer_insertion_flow!(
        model, fg_vehicles, fgs_commodities, nb_m
    )

    ## Set the optimizer and optimize

    # write_to_file(
    #     model,
    #     "model_test.lp";
    #     format = MOI.FileFormats.FORMAT_LP
    # )
    # set_optimizer_attribute(model, "ratioGap", 0.03)
    if optimizer === Gurobi.Optimizer
        if use_warm_start
            set_optimizer_attribute(model, "MIPGap", 0.005)
            set_optimizer_attribute(model, "TimeLimit", 20)
        end
        set_optimizer_attribute(model, "OutputFlag", 0)
        set_optimizer_attribute(model, "Method", 1)
    elseif optimizer === HiGHS.Optimizer
        if use_warm_start
            set_optimizer_attribute(model, "mip_rel_gap", 0.005)
            set_optimizer_attribute(model, "time_limit", 20)
        end
        set_optimizer_attribute(model, "output_flag", false)
        set_optimizer_attribute(model, "solver", "simplex")
        set_optimizer_attribute(model, "simplex_strategy", 1)
    end
    optimize!(model)

    # stat = termination_status(model)
    # @info "Termination status: $stat"

    return fg_vehicles, fgs_commodities, model, indices_m, old_possible_routes
end

"""
    fill_former_routes_customer_insertion!(instance::Instance,
                                            old_possible_routes::Vector{Route},
                                            flows::Array{Int},
                                            commodities_of_c::Array,
                                            fg_commodity::FlowGraph,
                                            customer_index::Int,
    )

Deduce from the flow variables the former routes to modify to deliver the customer indexed by `customer_index`.

The routes to fill are the `old_possible_routes`. We use the graph structure 
of `fg_commodity` to make a link between the routes' insertion positions and the indices of `flows` variable. 
We highlight the commodity flow graphs share the same arcs, thus one reference graph is usefull. 
"""
function fill_former_routes_customer_insertion!(
    instance::Instance,
    old_possible_routes::Vector{Route},
    flows::Array{Int},
    commodities_of_c::Array,
    fg_commodity::FlowGraph,
    customer_index::Int,
)
    ## Fill former routes
    M = instance.M
    l = [instance.commodities[m].l for m in 1:M]

    quty_former_routes = zeros(M)
    println("Fill former routes")
    for (r, route) in enumerate(old_possible_routes)
        n1 = FGN(; t=route.t, str="route_$r")
        index_n1 = get_vertexindex(fg_commodity, n1)
        route_updated = false
        for out_neighbor_index in outneighbors(fg_commodity, index_n1)
            edge12m = get_edgeindex(fg_commodity, index_n1, out_neighbor_index)
            sent_quantity = flows[:, edge12m]
            if sum(sent_quantity) > 0
                n2 = get_vertexlabel(fg_commodity, out_neighbor_index)
                route_updated = true
                new_route = copy(route)
                update_instance_some_routes!(instance, [route], "delete")
                Q = zeros(M)
                Q[BitArray(commodities_of_c)[:, 1]] = sent_quantity
                quty_former_routes += Q
                stop = RouteStop(; c=customer_index, t=n2.t, Q=Q)
                insert!(new_route.stops, n2.s, stop) #insert at proper position
                update_route_order!(new_route, instance, collect(1:get_nb_stops(new_route)))
                # optimize_route!(new_route, instance)
                compress!(new_route, instance)
                update_instance_some_routes!(instance, [new_route], "add")
            end
        end
        if !route_updated
            newroute = copy(route)
            update_instance_some_routes!(instance, [route], "delete")
            # optimize_route!(newroute, instance)
            compress!(newroute, instance)
            update_instance_some_routes!(instance, [newroute], "add")
        end
    end
    return println(
        "Total content sent by new routes: ", sum(quty_former_routes[m] * l[m] for m in 1:M)
    )
end

"""
    fill_new_routes_customer_insertion!(instance::Instance,
                                        fg_commodity::FlowGraph,
                                        flows::Array,
                                        indices_m::Vector,
                                        nb_m::Int,
                                        customer_index::Int,
    )

Create new routes solving bin packing problems involving quantities of `flows`.

We use the graph structure of `fg_commodity` to make a link between 
the routes to create and the indices of `flows` variable.
Only new direct routes are created since one customer is involved.
"""
function fill_new_routes_customer_insertion!(
    instance::Instance,
    fg_commodity::FlowGraph,
    flows::Array,
    indices_m::Vector,
    nb_m::Int,
    customer_index::Int,
)
    D, T, M = instance.D, instance.T, instance.M
    vehicle_capacity = instance.vehicle_capacity
    l = [instance.commodities[m].l for m in 1:M]

    ## New direct routes
    println("Fill new routes")
    sent_quantities = zeros(Int, M, D, T)

    #  Deduce sent quantities
    for (k, edge) in enumerate(edges(fg_commodity))
        n1 = get_vertexlabel(fg_commodity, src(edge))
        n2 = get_vertexlabel(fg_commodity, dst(edge))
        if n1.d > 0 && n2.c > 0
            t = n1.t
            d, c = n1.d, n2.c
            for i_m in 1:nb_m
                sent_quantities[indices_m[i_m], d, t] += flows[i_m, k]
            end
        end
    end
    # Fill new routes by bin packing
    sent_quantities_new_routes = sum(sent_quantities; dims=[2, 3])
    println(
        "Total content sent by new routes: ",
        sum(sent_quantities_new_routes[m] * l[m] for m in 1:M),
    )
    for t in 1:T, d in 1:D
        quant = sent_quantities[1:M, d, t]
        if sum(quant) == 0
            continue
        end
        items = [m for m in 1:M for n in 1:quant[m]]
        lengths = [l[m] for m in 1:M for n in 1:quant[m]]
        bin_items = first_fit_decreasing(items, lengths, vehicle_capacity)
        for bin in bin_items
            Q = zeros(Int, M)
            for m in bin
                Q[m] += 1
            end
            arrival_time =
                t + floor(
                    instance.transport_durations[d, D + customer_index] /
                    instance.nb_transport_hours_per_day,
                )
            stop = RouteStop(; c=customer_index, t=arrival_time, Q=Q)
            route = Route(; t=t, d=d, stops=[stop])
            update_instance_some_routes!(instance, [route], "add")
        end
    end
end

"""
    one_step_ruin_recreate_customer!(instance::Instance, customer_index::Int; optimizer)

Remove and insert the customer indexed by `customer_index` in the current solution.

We first remove the customer with [`remove_customer!`](@ref), then precompute costs, dates
and remaining capacities with [`location_and_cost_insertion!`](@ref), solve the reinsertion 
MILP with [`customer_insertion_flow`](@ref), then fill former and new routes with 
[`fill_former_routes_customer_insertion!`](@ref) and [`fill_new_routes_customer_insertion!`](@ref) respectively. 
A warmstart is performed to gain speed, initialized at the last solution.
"""
function one_step_ruin_recreate_customer!(
    instance::Instance, customer_index::Int; optimizer
)
    ## Save the former solution and cost 
    intial_solution = deepcopy(instance.solution)
    initial_cost = compute_cost(instance)

    ## Get information about the commodities
    M = instance.M
    commodities_of_c = commodities_used_customer(instance, customer_index)
    nb_m = sum(Int.(commodities_of_c))
    if nb_m == 0
        return false
    end

    ## Remove the customer from the solution
    println("Remove customer: ", customer_index)
    former_quantities_former_routes, former_quantities_new_routes = remove_customer!(
        instance, customer_index
    )

    ## Find the dedicated places costs and timing for insertion 
    routes = list_routes(instance.solution)
    costs, dates, places, old_possible_routes = location_and_cost_insertion!(
        instance, customer_index, routes
    )

    ## Get the flows from the former configuration
    println("Solve the initialization flow problem for $nb_m commodities")
    _, fgs_commodities, model, indices_m, old_possible_routes = customer_insertion_flow(
        instance;
        customer_index=customer_index,
        old_possible_routes=old_possible_routes,
        costs=costs,
        places=places,
        dates=dates,
        former_quantities_former_routes=former_quantities_former_routes,
        former_quantities_new_routes=former_quantities_new_routes,
        use_warm_start=false,
        force_values=true,
        values_vehicles_flow=ones(1),
        values_commodities_flows=ones(1),
    )
    flows_commodities = trunc.(Int, value.(model[:z]))
    flows_vehicles = trunc.(Int, value.(model[:x]))

    ## Solve the insertion problem with warm start
    println("Solve the insertion flow problem for $nb_m commodities")
    _, fgs_commodities, model, indices_m, old_possible_routes = customer_insertion_flow(
        instance;
        customer_index=customer_index,
        old_possible_routes=old_possible_routes,
        costs=costs,
        places=places,
        dates=dates,
        former_quantities_former_routes=former_quantities_former_routes,
        former_quantities_new_routes=former_quantities_new_routes,
        use_warm_start=true,
        force_values=false,
        values_vehicles_flow=flows_vehicles,
        values_commodities_flows=flows_commodities,
    )
    fg_commodity = fgs_commodities[1]
    flows_commodities = trunc.(Int, value.(model[:z]))

    ## Fill former routes
    fill_former_routes_customer_insertion!(
        instance,
        old_possible_routes,
        flows_commodities,
        commodities_of_c,
        fg_commodity,
        customer_index,
    )

    ## Fill new direct routes
    fill_new_routes_customer_insertion!(
        instance, fg_commodity, flows_commodities, indices_m, nb_m, customer_index
    )

    final_cost = compute_cost(instance)
    if (final_cost - initial_cost) / initial_cost > 0.01
        println("New cost: $final_cost, reset to initial solution")
        instance.solution = intial_solution
        update_instance_from_solution!(instance)
    end
    println("Cost after ruin and recreate: ", compute_cost(instance))
    return true
end
