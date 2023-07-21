## In this file we implement functions to withdraw and insert a commodity

"""
    remove_commodity!(instance::Instance; 
                        commodity_index::Int, 
                        delete_empty_routes::Bool = true
    )

Remove the commodity indexed by `commodity_index` from the routes of the solution.

We update the `instance` solution depending on `delete_empty_routes`.
If `true`, the routes with empty vehicles are deleted from the solution.
Else, they are kept.
"""
function remove_commodity!(
    instance::Instance; commodity_index::Int, delete_empty_routes::Bool=true
)
    M, D, C, T = instance.M, instance.D, instance.C, instance.T
    routes = list_routes(instance.solution)
    former_quantities_former_routes = Dict()
    former_quantities_new_routes = zeros(Int, M, D, C, T)
    for route in routes
        route_copy = mycopy(route)
        for stop in route_copy.stops
            stop.Q[commodity_index] = 0
        end
        if content_size(route_copy, instance) == 0 && delete_empty_routes
            update_instance_some_routes!(instance, [route], "delete")
            for stop in route.stops
                former_quantities_new_routes[commodity_index, route.d, stop.c, route.t] += stop.Q[commodity_index]
            end
        else
            update_instance_some_routes!(instance, [route], "delete")
            update_instance_some_routes!(instance, [route_copy], "add")
            quantities_in_former_route = []
            for stop in route.stops
                append!(quantities_in_former_route, stop.Q[commodity_index])
            end
            former_quantities_former_routes[route_copy.id] = quantities_in_former_route
        end
    end
    return former_quantities_former_routes, former_quantities_new_routes
end

"""
    commodity_insertion_MILP(instance::Instance;
                                optimizer,
                                commodity_index::Int,
                                integer::Bool,
                                maxdist::Real,
                                former_quantities_former_routes::Dict,
                                former_quantities_new_routes::Array,
                                force_values::Bool,
                                values_vehicles_flow::Array,
                                values_commodities_flows::Array,
                                use_warm_start::Bool
    )

Define and solve the MILP for the reinsertion of commodity indexed by `commodity_index`.

We choose integer variables with the boolean `integer`.

We possibly sparsify the graphs with `maxdist`, and force the values on 
former and new routes using `force_values` boolean and `former_quantities_former_routes`
and `former_quantities_new_routes` information, see [`commodity_flow_graph`](@ref).

We can use a warmstart if `use_warm_start` is `true`, with the values of the flows set 
to `values_commodities_flows` and `values_vehicles_flow`.
"""
function commodity_insertion_MILP(
    instance::Instance;
    optimizer,
    commodity_index::Int,
    integer::Bool,
    maxdist::Real,
    former_quantities_former_routes::Dict,
    former_quantities_new_routes::Array,
    force_values::Bool,
    values_vehicles_flow::Array,
    values_commodities_flows::Array,
    use_warm_start::Bool,
)
    ## Get dimensions
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    vehicle_capacity = instance.vehicle_capacity
    l = [instance.commodities[m].l for m in 1:M]
    concerned_depots = select_relevant_depots(instance, commodity_index)
    list_depots = [d for d in 1:D if concerned_depots[d] == 1]
    concerned_customers = select_relevant_customers(instance, commodity_index)
    list_customers = [c for c in 1:C if concerned_customers[c] == 1]

    routes = list_routes(instance.solution)

    model = Model(optimizer)

    # Vehicle flow: the new routes are direct for the moment
    fg_vehicles = expanded_vehicle_flow_graph(instance; S_max=1, maxdist=maxdist)

    # Variable
    @variable(model, x[1:ne(fg_vehicles)] >= 0, integer = integer)
    if use_warm_start
        set_start_value.(x, values_vehicles_flow)
    end
    add_flow_constraints!(model, model[:x], fg_vehicles)

    # Commodity flow
    fg_commodity = commodity_flow_graph(
        instance;
        commodity_index=commodity_index,
        S_max=1,
        maxdist=Inf,
        relaxed_trip_cost=false,
        average_content_sizes=nothing,
        force_routes_values=force_values,
        sent_quantities_to_force=former_quantities_new_routes,
        sparsify=true,
    )

    old_possible_routes_indices = Vector{Int}()
    # Add non-saturated routes in the commodity graph
    @showprogress "Non-saturated routes added " for (r, route) in enumerate(routes)
        # in case the depot is not concerned by the commodity
        if concerned_depots[route.d] != 1
            continue
        end

        remaining_space = vehicle_capacity - content_size(route, instance)

        if floor(remaining_space / l[commodity_index]) == 0
            continue
        end

        append!(old_possible_routes_indices, r)
        t = route.t
        d = route.d

        # add nodes
        for (s, stop) in enumerate(route.stops)
            arrival_date = stop.t
            c = stop.c
            add_vertex!(fg_commodity, FGN(; t=arrival_date, c=c, s=s, str="noon_route_$r"))
        end

        # add arcs
        # d => c
        n1 = FGN(; t=t, d=d, str="morning")
        n2 = FGN(; t=route.stops[1].t, c=route.stops[1].c, s=1, str="noon_route_$r")
        add_edge!(fg_commodity, n1, n2)
        set_capa_max!(
            fg_commodity, ne(fg_commodity), floor(remaining_space / l[commodity_index])
        )

        # c1 => c2
        for s in 1:(length(route.stops) - 1)
            n1 = FGN(; t=route.stops[s].t, c=route.stops[s].c, s=s, str="noon_route_$r")
            n2 = FGN(;
                t=route.stops[s + 1].t,
                c=route.stops[s + 1].c,
                s=(s + 1),
                str="noon_route_$r",
            )
            add_edge!(fg_commodity, n1, n2)
        end

        # c_noon => c_evening
        for s in 1:length(route.stops)
            if concerned_customers[route.stops[s].c] == 1
                n1 = FGN(; t=route.stops[s].t, c=route.stops[s].c, s=s, str="noon_route_$r")
                n2 = FGN(; t=route.stops[s].t, c=route.stops[s].c, str="evening")
                add_edge!(fg_commodity, n1, n2)
                if force_values
                    set_value!(
                        fg_commodity,
                        ne(fg_commodity),
                        former_quantities_former_routes[route.id][s],
                    )
                end
            end
        end
    end

    # Variable
    @variable(model, z[1:ne(fg_commodity)] >= 0, integer = integer)
    if use_warm_start
        set_start_value.(z, values_commodities_flows)
    end
    add_flow_constraints!(model, model[:z], fg_commodity)

    # Coupling constraints vehicles - commodity

    # Trip d => c
    @showprogress "Link trips d=>c " for d in list_depots, c in list_customers, t in 1:T
        n1 = FGN(; t=t, d=d, str="morning")
        arrival_date =
            t + floor(
                instance.transport_durations[d, D + c] / instance.nb_transport_hours_per_day
            )
        if arrival_date <= T
            n2 = FGN(; t=arrival_date, c=c, s=1, str="noon")
            edge12commodity = get_edgeindex(fg_commodity, n1, n2)
            edge12vehicles = get_edgeindex(fg_vehicles, n1, n2)
            @constraint(
                model,
                model[:z][edge12commodity] <=
                    model[:x][edge12vehicles] * floor(vehicle_capacity / l[commodity_index])
            )
        end
    end

    # Objective function
    obj = AffExpr(0.0)
    add_flow_cost!(obj, model[:x], fg_vehicles)
    add_flow_cost!(obj, model[:z], fg_commodity)
    @objective(model, Min, obj)

    if optimizer === Gurobi.Optimizer
        set_optimizer_attribute(model, "OutputFlag", 0) # TODO
        set_optimizer_attribute(model, "TimeLimit", 20)
        set_optimizer_attribute(model, "MIPGap", 0.005)
        set_optimizer_attribute(model, "Method", 1)
    elseif optimizer === HiGHS.Optimizer
        set_optimizer_attribute(model, "output_flag", false)
        set_optimizer_attribute(model, "time_limit", 20.0)
        set_optimizer_attribute(model, "mip_rel_gap", 0.005)
    end
    optimize!(model)
    #stat = termination_status(model)

    return fg_vehicles, fg_commodity, model, old_possible_routes_indices
end

"""
    fill_former_routes_commodity_insertion!(instance::Instance,
                                            old_possible_routes_indices::Vector{Int},
                                            flow_commodity::Vector{Int},
                                            fg_commodity::FlowGraph,
                                            commodity_index::Int,
    )

Fill the former routes with commodity `commodity_index` reading the flow variables.

The routes to fill are indexed by `old_possible_routes_indices`.
We use the graph structure of `fg_commodity` to make a link between 
the routes and the indices of the `flow_commodity` `Vector`.
"""
function fill_former_routes_commodity_insertion!(
    instance::Instance,
    old_possible_routes_indices::Vector{Int},
    flow_commodity::Vector{Int},
    fg_commodity::FlowGraph,
    commodity_index::Int,
)
    routes = list_routes(instance.solution)
    concerned_customers = select_relevant_customers(instance, commodity_index)
    quantity_former_routes = 0
    for ind_r in old_possible_routes_indices
        route = routes[ind_r]
        t = route.t
        for (s, stop) in enumerate(route.stops)
            if concerned_customers[stop.c] != 1
                continue
            end
            n1 = FGN(; t=stop.t, c=stop.c, s=s, str="noon_route_$ind_r")
            n2 = FGN(; t=stop.t, c=stop.c, str="evening")
            edge12commodity = get_edgeindex(fg_commodity, n1, n2)
            if flow_commodity[edge12commodity] > 0
                stop.Q[commodity_index] = flow_commodity[edge12commodity]
                quantity_former_routes += flow_commodity[edge12commodity]
                if !feasibility(instance.customers[stop.c])
                    print(concerned_customers[c])

                    println("Fill wrong customer in a former route!!")
                    feasibility(instance.customers[c]; verbose=true)
                end
            end
        end
    end
    update_instance_from_solution!(instance, commodity_index)
    return println("Quantity sent by former routes:", quantity_former_routes)
end

"""
    fill_new_routes_commodity_insertion!(instance::Instance,
                                            fg_commodity::FlowGraph,
                                            flow_commodity::Vector{Int},
                                            commodity_index::Int,
    )

Create new routes solving bin packing problems involving the flow `flow_commodity`.

We use the graph structure of `fg_commodity` to make a link between 
the routes to create and the indices of the `flow_commodity` `Vector`.
We restrict those new routes to be direct.
"""
function fill_new_routes_commodity_insertion!(
    instance::Instance,
    fg_commodity::FlowGraph,
    flow_commodity::Vector{Int},
    commodity_index::Int,
)
    M = instance.M
    vehicle_capacity = instance.vehicle_capacity
    l = [instance.commodities[m].l for m in 1:M]
    sent_by_new_routes = 0
    #  Deduce sent quantities
    for (k, edge) in enumerate(edges(fg_commodity))
        n1 = get_vertexlabel(fg_commodity, src(edge))
        n2 = get_vertexlabel(fg_commodity, dst(edge))
        if n1.d > 0 && n2.c > 0 && n2.str == "noon"
            t = n1.t
            arrival_date = n2.t
            d, c = n1.d, n2.c
            quantity_dc = flow_commodity[k]
            sent_by_new_routes += quantity_dc
            while quantity_dc > 0
                Q = zeros(Int, M)
                Q[commodity_index] = min(
                    floor(vehicle_capacity / l[commodity_index]), quantity_dc
                )
                quantity_dc -= Q[commodity_index]
                stop = RouteStop(; c=c, t=arrival_date, Q=Q)
                route = Route(; t=t, d=d, stops=[stop])
                update_instance_some_routes!(instance, [route], "add")
                if !feasibility(instance.customers[c])
                    println("Fill wrong customer in a new route !!")
                    feasibility(instance.customers[c]; verbose=true)
                end
            end
        end
    end
    return println("Quantity sent by new routes:", sent_by_new_routes)
end

"""
    one_step_ruin_recreate_commodity!(instance::Instance;
                                        optimizer,
                                        commodity_index::Int,
                                        integer::Bool,
                                        maxdist::Real,
                                        delete_empty_routes::Bool = true,
    )   

Remove and insert the commodity indexed by `commodity_index` in the current solution.

We first remove the commodity with [`remove_commodity!`](@ref), then solve the reinsertion 
MILP with [`commodity_insertion_MILP`](@ref), then fill former and new routes with 
[`fill_former_routes_commodity_insertion!`](@ref) and [`fill_new_routes_commodity_insertion!`](@ref) respectively. 
A warmstart is performed to gain speed, initialized at the last solution.
"""
function one_step_ruin_recreate_commodity!(
    instance::Instance;
    optimizer,
    commodity_index::Int,
    integer::Bool,
    maxdist::Real,
    delete_empty_routes::Bool=true,
)

    ## Save the former solution and cost 
    intial_solution = deepcopy(instance.solution)
    initial_cost = compute_cost(instance)

    ## Remove the commodity from the solution
    println("Remove commodity: ", commodity_index)
    former_quantities_former_routes, former_quantities_new_routes = remove_commodity!(
        instance; commodity_index=commodity_index, delete_empty_routes=delete_empty_routes
    )

    ## Initialize with the former configuration
    println("Solve the initialization flow problem")

    _, fg_commodity, model, old_possible_routes_indices = commodity_insertion_MILP(
        instance;
        optimizer,
        commodity_index=commodity_index,
        integer=integer,
        maxdist=maxdist,
        former_quantities_former_routes=former_quantities_former_routes,
        former_quantities_new_routes=former_quantities_new_routes,
        force_values=true,
        values_vehicles_flow=zeros(1),
        values_commodities_flows=zeros(1),
        use_warm_start=false,
    )

    if !has_values(model)
        instance.solution = intial_solution
        update_instance_from_solution!(instance)
        return false
    end
    flow_commodity = trunc.(Int, value.(model[:z]))
    flow_vehicle = trunc.(Int, value.(model[:x]))

    ## Solve the insertion MILP with warm start
    _, fg_commodity, model, old_possible_routes_indices = commodity_insertion_MILP(
        instance;
        optimizer,
        commodity_index=commodity_index,
        integer=integer,
        maxdist=maxdist,
        former_quantities_former_routes=former_quantities_former_routes,
        former_quantities_new_routes=former_quantities_new_routes,
        force_values=false,
        values_vehicles_flow=flow_vehicle,
        values_commodities_flows=flow_commodity,
        use_warm_start=true,
    )

    if !has_values(model)
        instance.solution = intial_solution
        update_instance_from_solution!(instance)
        return false
    end

    flow_commodity = trunc.(Int, value.(model[:z]))

    ## Fill former routes
    fill_former_routes_commodity_insertion!(
        instance, old_possible_routes_indices, flow_commodity, fg_commodity, commodity_index
    )

    ## Fill new direct routes
    fill_new_routes_commodity_insertion!(
        instance, fg_commodity, flow_commodity, commodity_index
    )

    final_cost = compute_cost(instance)
    if (final_cost - initial_cost) / initial_cost > 0.05
        println("New cost: $final_cost, reset to initial solution")
        instance.solution = intial_solution
        update_instance_from_solution!(instance)
    end
    println("Cost after ruin and recreate: ", compute_cost(instance))
    return true
end
