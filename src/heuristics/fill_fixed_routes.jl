"""
    fill_fixed_routes_MILP(instance::Instance;
                            fixed_routes::Vector{Route},
                            fixed_routes_costs::Vector{Int},
                            integer::Bool = true,
                            verbose::Bool = true,
                            refill_neighborhood::Bool = false,
                            force_quantities::Bool = false,
                            use_warm_start::Bool = false,
                            values_commodity_flows::Matrix{Int}
    )

Given a set of `fixed_routes`, use them or not, and fill the used-ones with commodities.

When solved to optimality, this MILP is the exact decision problem of optimizing the 
use and deliveries inherent in a set of routes (paths).
The boolean `force_quantities` is used to solve a degenerate MILP with sent quantities set 
to the previous values. It is used to provide a first solution as `values_commodity_flows` to 
a second call of this function with `use_warm_start` set to `true`, to solve the MILP with
a warm start.
"""
function fill_fixed_routes_MILP(
    instance::Instance;
    fixed_routes::Vector{Route},
    fixed_routes_costs::Vector{Int},
    integer::Bool=true,
    verbose::Bool=true,
    refill_neighborhood::Bool=false,
    force_quantities::Bool=false,
    use_warm_start::Bool=false,
    values_commodity_flows::Matrix{Int},
)
    # Dimensions
    M = instance.M
    l = [instance.commodities[m].l for m in 1:M]
    vehicle_capacity = instance.vehicle_capacity

    # Solver environment and model
    model = Model(Gurobi.Optimizer)

    # Vehicles graph and variable 
    @variable(model, x[1:length(fixed_routes)] >= 0, binary = true)
    if use_warm_start
        set_start_value.(x, ones(length(fixed_routes)))
    end

    # Commodities graphs and variables 
    fgs_commodities = Vector{FlowGraph}(undef, M)
    fg_commodity_ref = commodity_flow_graph(
        instance;
        commodity_index=1,
        add_new_routes_arcs=false,
        fixed_routes=fixed_routes,
        refill_neighborhood=refill_neighborhood,
    )
    @variable(model, y[1:M, 1:ne(fg_commodity_ref)] >= 0, integer = integer)
    if use_warm_start
        set_start_value.(y, values_commodity_flows)
    end
    @showprogress "Commodities flow graphs " for m in 1:M
        fgs_commodities[m] = commodity_flow_graph(
            instance;
            commodity_index=m,
            add_new_routes_arcs=false,
            fixed_routes=fixed_routes,
            refill_neighborhood=refill_neighborhood,
            force_routes_values=force_quantities,
        )
        add_flow_constraints!(model, model[:y][m, :], fgs_commodities[m])
    end

    # Coupling constraints 
    @showprogress "Coupling constraints on the roads" for (r, route) in
                                                          enumerate(fixed_routes)
        n1 = FGN(; t=route.t, d=route.d, str="morning")
        n2 = FGN(; t=route.stops[1].t, c=route.stops[1].c, s=1, str="noon_route_$r")
        edge12commodity = get_edgeindex(fg_commodity_ref, n1, n2)
        @constraint(
            model,
            sum(model[:y][m, edge12commodity] * l[m] for m in 1:M) <=
                model[:x][r] * vehicle_capacity
        )
    end

    # objective function
    obj = AffExpr(0.0)
    for r in 1:length(fixed_routes)
        add_to_expression!(obj, fixed_routes_costs[r], model[:x][r])
    end
    @showprogress "Commodities objective function" for m in 1:M
        add_flow_cost!(obj, model[:y][m, :], fgs_commodities[m])
    end
    @objective(model, Min, obj)

    # Optimize the model 
    set_optimizer_attribute(model, "MIPGap", 0.05)
    set_optimizer_attribute(model, "TimeLimit", 120)
    set_optimizer_attribute(model, "Method", 1)
    set_optimizer_attribute(model, "OutputFlag", 0)
    optimize!(model)

    verbose && println(objective_value(model))
    return fgs_commodities, model
end

"""
    decode_MILP_solution!(instance::Instance;
                            fixed_routes::Vector{Route},
                            flow_commodities::Matrix{Int},
                            fgs_commodities::Vector{FlowGraph},
    )

Given the solution of the MILP in [`fill_fixed_routes_MILP`](@ref), fill `fixed_routes`.

We use `fgs_commodities` to link the `flow_commodities` variables indices with the 
corresponding routes to fill in `fixed_routes`.
"""
function decode_MILP_solution!(
    instance::Instance;
    fixed_routes::Vector{Route},
    flow_commodities::Matrix{Int},
    fgs_commodities::Vector{FlowGraph},
)
    M = instance.M
    routes_to_delete = Vector{Int}()
    for (r, route) in enumerate(fixed_routes)
        for (s, stop) in enumerate(route.stops)
            n1 = FGN(; t=stop.t, c=stop.c, s=s, str="noon_route_$r")
            n2 = FGN(; t=stop.t, c=stop.c, str="evening")
            edge12commodity = get_edgeindex(fgs_commodities[1], n1, n2) ## common arc indexing
            for m in 1:M
                stop.Q[m] = flow_commodities[m, edge12commodity]
            end
        end
        if content_size(route, instance) == 0
            append!(routes_to_delete, r)
        end
    end
    delete_routes!(instance.solution, fixed_routes[routes_to_delete])
    return update_instance_from_solution!(instance)
end

"""
    refill_routes!(instance::Instance; 
                        fixed_routes::Vector{Route}, 
                        fixed_routes_costs::Vector{Int}, 
                        verbose::Bool = false,
                        refill_neighborhood::Bool = false,
                        stats::Union{Dict, Nothing} = nothing,
    )

Given a set of routes, empty them, solve the refill MILP and decode the solution.

The routes to consider and corresponding costs are stored in `fixed_routes`
and `fixed_routes_costs` respectively. It can be used in a large neighborhood,
which entails fixing a part of the solution and creating special nodes and arcs in the 
commodity flow graphs (see [`commodity_flow_graph`](@ref)), 
indicated by the boolean `refill_neighborhood`.
"""
function refill_routes!(
    instance::Instance;
    fixed_routes::Vector{Route},
    fixed_routes_costs::Vector{Int},
    verbose::Bool=false,
    refill_neighborhood::Bool=false,
    stats::Union{Dict,Nothing}=nothing,
)
    # Initial cost 
    oldcost = compute_cost(instance)
    # The routes in the current solution
    # clusters = decouple_routes(fixed_routes)
    # println("There are $(length(unique(clusters))) clusters of routes")

    # Update the instance removing quantities of the fixed_routes
    if length(fixed_routes) == 0
        return false
    end
    update_instance_some_routes!(instance, fixed_routes, "delete", false)

    # solve the MILP to refill the fixed routes with initial forced values to send
    fgs_commodities, model = fill_fixed_routes_MILP(
        instance;
        fixed_routes=fixed_routes,
        fixed_routes_costs=fixed_routes_costs,
        integer=true,
        verbose=verbose,
        refill_neighborhood=refill_neighborhood,
        force_quantities=true,
        use_warm_start=false,
        values_commodity_flows=zeros(Int, (1, 1)),
    )
    flow_commodities = Matrix{Int}(trunc.(Int, value.(model[:y])))

    # solve again with warm start using the former solution
    fgs_commodities, model = fill_fixed_routes_MILP(
        instance;
        fixed_routes=fixed_routes,
        fixed_routes_costs=fixed_routes_costs,
        integer=true,
        verbose=verbose,
        refill_neighborhood=refill_neighborhood,
        force_quantities=false,
        use_warm_start=true,
        values_commodity_flows=flow_commodities,
    )
    flow_commodities = Matrix{Int}(trunc.(Int, value.(model[:y])))

    # update the instance using the MILP solution 
    decode_MILP_solution!(
        instance;
        fixed_routes=fixed_routes,
        flow_commodities=flow_commodities,
        fgs_commodities=fgs_commodities,
    )
    @assert(feasibility(instance, verbose=true))
    newcost = compute_cost(instance)
    verbose && println("COST AFTER REFILL ROUTES = $newcost")
    if !isnothing(stats)
        stats["gain_refill_routes"] += newcost - oldcost
    end
    return true
end

"""
    refill_routes_from_depot!(instance::Instance; 
                                depot_index::Int, 
                                verbose::Bool = false, 
                                stats::Union{Dict, Nothing} = nothing
    )

Refill all the routes that start from a given depot indexed by `depot_index`.

In this case we use [`refill_routes!`](@ref) as a large neighborhood.
"""
function refill_routes_from_depot!(
    instance::Instance;
    depot_index::Int,
    verbose::Bool=false,
    stats::Union{Dict,Nothing}=nothing,
)
    # Select the routes to refill 
    fixed_routes = list_routes_depot(instance.solution, depot_index)
    fixed_routes_costs = [compute_route_cost(route, instance) for route in fixed_routes]
    # Apply the refill_route framework
    return refill_routes!(
        instance;
        fixed_routes=fixed_routes,
        fixed_routes_costs=fixed_routes_costs,
        verbose=verbose,
        refill_neighborhood=true,
        stats=stats,
    )
end

"""
    refill_routes_on_day!(instance::Instance; 
                            t::Int, 
                            verbose::Bool = false, 
                            stats::Union{Dict, Nothing} = nothing
    )

Refill all the routes that start on a given day `t`.

In this case we use [`refill_routes!`](@ref) as a large neighborhood.
"""
function refill_routes_on_day!(
    instance::Instance; t::Int, verbose::Bool=false, stats::Union{Dict,Nothing}=nothing
)
    # Select the routes to refill 
    fixed_routes = list_routes(instance.solution, t)
    fixed_routes_costs = [compute_route_cost(route, instance) for route in fixed_routes]
    # Apply the refill_route framework
    return refill_routes!(
        instance;
        fixed_routes=fixed_routes,
        fixed_routes_costs=fixed_routes_costs,
        verbose=verbose,
        refill_neighborhood=true,
        stats=stats,
    )
end

"""
    refill_every_route!(instance::Instance; verbose::Bool = false)

Refill all the routes of a solution at once.

In this case we use [`refill_routes!`](@ref) on the whole set 
of routes in the current solution of `instance`.

We emphasize that this exact MILP may be too large to 
solve in practice for big IRP instances. We thus suggest some ways to 
fix a part of the solution and use it as large neighborhood.
"""
function refill_every_route!(instance::Instance; verbose::Bool=false)
    # Select the routes to refill 
    fixed_routes = list_routes(instance.solution)
    fixed_routes_costs = [compute_route_cost(route, instance) for route in fixed_routes]
    # Apply the refill_route framework
    return refill_routes!(
        instance;
        fixed_routes=fixed_routes,
        fixed_routes_costs=fixed_routes_costs,
        verbose=verbose,
        refill_neighborhood=false,
    )
end

"""
    refill_iterative_depot!(instance::Instance; 
                            verbose::Bool = false, 
                            stats::Union{Dict, Nothing} = nothing
    )

Apply [`refill_routes_from_depot!`](@ref) depot-by-depot.

Contrary to [`refill_every_route!`](@ref), this iterative way of 
refilling every route of a solution can be used on large instances.
"""
function refill_iterative_depot!(
    instance::Instance; verbose::Bool=false, stats::Union{Dict,Nothing}=nothing
)
    @showprogress "Refill the routes starting at each depot" for d in 1:(instance.D)
        stats["duration_refill_routes"] += @elapsed refill_routes_from_depot!(
            instance; depot_index=d, verbose=verbose, stats=stats
        )
        if compute_total_time(stats) > stats["time_limit"]
            return nothing
        end
    end
end

"""
    refill_iterative_days!(instance::Instance; 
                            verbose::Bool = false, 
                            stats::Union{Dict, Nothing} = nothing
    )

Apply [`refill_routes_on_day!`](@ref) day-by-day.

Contrary to [`refill_every_route!`](@ref), this iterative way of 
refilling every route of a solution can be used on large instances.
"""
function refill_iterative_days!(
    instance::Instance; verbose::Bool=false, stats::Union{Dict,Nothing}=nothing
)
    @showprogress "Refill the routes starting on each day" for t in 1:(instance.T)
        refill_routes_on_day!(instance; t=t, verbose=verbose, stats=stats)
    end
end

"""
    refill_iterative_commodity_reinsertion!(instance::Instance; 
                                            stats::Union{Nothing, Dict} = nothing, 
                                            verbose::Bool = false
    )

Apply [`one_step_ruin_recreate_commodity!`](@ref) commodity-by-commodity.

Contrary to [`refill_every_route!`](@ref), this iterative way of 
refilling every route of a solution can be used on large instances.
"""
function refill_iterative_commodity_reinsertion!(
    instance::Instance; stats::Union{Nothing,Dict}=nothing, verbose::Bool=false
)
    M = instance.M
    l = [instance.commodities[m].l for m in 1:M]
    order = sortperm(l; rev=true)

    # Reset the solution
    @showprogress "remove quantities from routes" for route in
                                                      list_routes(instance.solution)
        for stop in route.stops
            stop.Q .= 0
        end
    end
    update_instance_from_solution!(instance)
    # Iteratively apply commodity reinsertion over the whole set of commodities
    for commodity_index in order[1:M]
        one_step_ruin_recreate_commodity!(
            instance;
            commodity_index=commodity_index,
            integer=true,
            maxdist=Inf,
            delete_empty_routes=false,
        )
    end
    # single depot local search to finish
    return single_depot_local_search!(
        instance; maxdist=Inf, verbose=verbose, stats=stats, in_LNS=false
    )
end
