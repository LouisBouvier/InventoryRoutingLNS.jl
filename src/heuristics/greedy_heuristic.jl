"""
    fill_trucks!(instance::Instance; sent_quantities::Array{Int,4})

Update `instance` with new routes deduced from a bin packing based on `sent_quantities`.
"""
function fill_trucks!(instance::Instance; sent_quantities::Array{Int,4})
    reset_solution!(instance)
    D, C, T, M = instance.D, instance.C, instance.T, instance.M
    vehicle_capacity = instance.vehicle_capacity
    transport_durations = instance.transport_durations
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    l = [instance.commodities[m].l for m = 1:M]

    for t = 1:T, d = 1:D, c = 1:C
        quant = sent_quantities[1:M, d, c, t]
        if sum(quant) == 0
            continue
        end
        items = [m for m = 1:M for n = 1:quant[m]]
        lengths = [l[m] for m = 1:M for n = 1:quant[m]]
        bin_items = first_fit_decreasing(items, lengths, vehicle_capacity)
        for bin in bin_items
            Q = zeros(Int, M)
            for m in bin
                Q[m] += 1
            end
            t_c = t + floor(transport_durations[d, D+c] / nb_transport_hours_per_day)
            stop = RouteStop(c = c, t = t_c, Q = Q)
            route = Route(t = t, d = d, stops = [stop])
            add_route!(instance.solution, route)
        end
    end

    update_instance_from_solution!(instance)
    return instance
end

"""
    initialization_plus_ls!(instance::Instance;
                        maxdist::Real = Inf,
                        average_content_sizes::Union{Nothing,AverageContentSizes} = nothing,
                        verbose::Bool = true,
                        reset_after::Bool = false,
                        stats::Union{Nothing, Dict} = nothing,
                        sent_quantities::Union{Nothing, Array{Int,4}} = nothing,
    )

Apply a flow initialization followed by a single-depot localsearch to `instance`.

We first choose the quantities to send with the flow problem, initialize the IRP 
solution with iterative bin packin problems, and then improve the solution with 
single-depot moves.

The `maxdist` argument is used to sparsify graphs based on distances, see
[`commodity_flow_graph`](@ref) for the details.

The `average_content_sizes` data is used when using statistics of a former pass to 
re-estimate the routing arc costs on the commodity flow graphs. 
See [`modified_capa_initialization_plus_ls!`](@ref) for the details of this process.

The `reset_after` boolean is to decide to reset the `instance` solution after 
this greedy_heuristic or not. 

Instead of using the flows to initialize the quantities to send, we can use 
the `sent_quantities` values. This is done to show that the flows decoded from 
the [`LNS!`](@ref) solution are good solutions to the IRP when decoded by this function.
"""
function initialization_plus_ls!(
    instance::Instance;
    maxdist::Real = Inf,
    average_content_sizes::Union{Nothing,AverageContentSizes} = nothing,
    verbose::Bool = true,
    reset_after::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
    sent_quantities::Union{Nothing, Array{Int,4}} = nothing,
)

    verbose && println("\n\nINITIALIZATION PLUS LS\n\n")
    verbose && println("Cost without vehicle: ", compute_cost(instance))

    if sent_quantities === nothing
        flows_value, sent_quantities =
            solve_flows_initial_solution(instance, average_content_sizes = average_content_sizes)
        verbose && println("Cost of the flows problem: ", flows_value)
    end

    fill_trucks!(instance, sent_quantities = sent_quantities)
    verbose && println("Cost before local search: ", compute_cost(instance))
    verbose && println("Nb of vehicles before local search: ", nb_routes(instance.solution))

    single_depot_local_search!(
        instance,
        maxdist = maxdist,
        verbose = verbose,
        stats = stats,
        in_LNS = false,
    )
    verbose && println("Final cost: ", compute_cost(instance))
    verbose && println("Final nb of vehicles: ", nb_routes(instance.solution))

    reset_after && reset_solution!(instance)
end

"""
    modified_capa_initialization_plus_ls!(instance::Instance;
                                    maxdist::Real = Inf,
                                    verbose::Bool = true,
                                    stats::Dict = nothing,
    )

Apply [`initialization_plus_ls!`](@ref) two times and update costs from statistics of the first pass.

The `maxdist` argument is used to sparsify graphs based on distances, see
[`commodity_flow_graph`](@ref) for the details.
"""
function modified_capa_initialization_plus_ls!(
    instance::Instance;
    maxdist::Real = Inf,
    verbose::Bool = true,
    stats::Dict = nothing,
)
    initialization_plus_ls!(instance, maxdist = maxdist, verbose = verbose, stats = stats)
    compute_cost(instance, verbose = verbose)
    average_content_sizes = AverageContentSizes(instance)
    initialization_plus_ls!(
        instance,
        maxdist = maxdist,
        average_content_sizes = average_content_sizes,
        verbose = verbose,
        stats = stats,
    )
    compute_cost(instance, verbose = verbose)
end
