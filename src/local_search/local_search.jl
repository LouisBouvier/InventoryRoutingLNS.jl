"""
    TSP_local_search!(instance::Instance;
                        niter::Int = 1,
                        verbose::Bool = false,
                        stats::Union{Nothing, Dict} = nothing,
                        in_LNS::Bool = true,
    )

Apply `niter` for loops on the routes of the solution of `instance` to apply [`iterative_TSP_neighborhood!`](@ref).

The three types of TSP neighborhoods are tested.    
The `in_LNS` boolean is used to choose in which category the statistics 
are included (either in the greedy initialization heuristic if `false` 
or the neighborhood of the LNS if `true`).
"""
function TSP_local_search!(
    instance::Instance;
    niter::Int = 1,
    verbose::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
    in_LNS::Bool = true,
)
    verbose && println("\n\nTSP LOCAL SEARCH\n\n")
    for k = 1:niter 
        verbose && println("Iteration $k of the localsearch")
        @showprogress "Browse the routes with TSP moves: " for route in list_routes(instance.solution)
            # first apply relocate
            iterative_TSP_neighborhood!(route = route, instance = instance, neighborhood_index = 1, stats = stats, in_LNS = in_LNS)
            # then apply swap
            iterative_TSP_neighborhood!(route = route, instance = instance, neighborhood_index = 2, stats = stats, in_LNS = in_LNS)
            # last apply two opt star
            iterative_TSP_neighborhood!(route = route, instance = instance, neighborhood_index = 3, stats = stats, in_LNS = in_LNS)
        end
    end
    verbose && println("Cost after TSP localsearch: ", compute_cost(instance))
end


"""
    single_depot_local_search!(instance::Instance;
                                maxdist::Real = Inf,
                                niter::Int = 1,
                                verbose::Bool = false,
                                stats::Union{Nothing, Dict} = nothing,
                                in_LNS::Bool = true,
    )

Single-depot localsearch based on `merge`, `delete`, `insert` and `swap`, and TSP neighborhoods.

We pass `niter` times on each type of neighborhood.
"""
function single_depot_local_search!(
    instance::Instance;
    maxdist::Real = Inf,
    niter::Int = 1,
    verbose::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
    in_LNS::Bool = true,
)
    verbose && println("\n\nSINGLE DEPOT LOCAL SEARCH\n\n")
    for k = 1:niter
        verbose && println("Iteration $k of the localsearch")
        iterative_merge!(instance, verbose, stats = stats, in_LNS = in_LNS)
        iterative_merge_multiday!(instance, verbose, stats = stats, in_LNS = in_LNS)
        delete_non_profitable_routes!(instance, verbose, stats = stats, in_LNS = in_LNS)
        insert_swap_single_depot_routes!(instance, verbose, stats = stats, in_LNS = in_LNS)
        TSP_local_search!(instance, niter = 1, verbose = verbose, stats = stats, in_LNS = in_LNS)
    end
    verbose && println("End of the single depot localsearch")
    nothing
end

"""
    multi_depot_local_search!(instance::Instance;
                                niter::Int,
                                verbose::Bool = false,
                                stats::Union{Nothing, Dict} = nothing,
                                in_LNS::Bool = true,
    )

Multi-depot localsearch based on TSP, single-depot SDVRP and multi-depot SDVRP neighborhoods.

We pass `niter` times on each type of neighborhood.
"""
function multi_depot_local_search!(
    instance::Instance;
    niter::Int,
    verbose::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
    in_LNS::Bool = true,
)
    verbose && println("\n\nMULTI DEPOT LOCAL SEARCH\n\n")
    cost = 0
    newcost = 0
    for k = 1:niter
        insert_swap_multi_depot_per_day!(instance, stats = stats)
        delete_non_profitable_routes!(instance, verbose, stats = stats, in_LNS = in_LNS)
        two_opt_star_multi_depot_per_day!(instance, stats = stats)
        delete_non_profitable_routes!(instance, verbose, stats = stats, in_LNS = in_LNS)
        single_depot_local_search!(
            instance,
            maxdist = Inf,
            verbose = verbose,
            stats = stats,
            in_LNS = in_LNS,
        )
        delete_non_profitable_routes!(instance, verbose, stats = stats, in_LNS = in_LNS)
        iterative_change_day!(instance, "random", stats = stats)
        if k == 1
            cost = compute_cost(instance)
            verbose && println("Cost after localsearch iteration: ", cost)
        else
            newcost = compute_cost(instance)
            verbose && println("Cost after localsearch iteration: ", newcost)
            #if (cost-newcost)/cost < 0.0005
            #    break
            #end
            cost = newcost
        end
    end
    nothing
end

"""
    iterative_ruin_recreate_customer!(instance::Instance;
                                        niter::Int,
                                        verbose::Bool = false,
                                        at_random::Bool = false,
                                        stats::Union{Nothing, Dict} = nothing,
    )

Apply [`one_step_ruin_recreate_customer!`](@ref) `niter` times on customers.
Two possibilities: select customers at random, or by decreasing cost order.
"""
function iterative_ruin_recreate_customer!(
    instance::Instance;
    niter::Int,
    verbose::Bool = false,
    at_random::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
)
    verbose && println("\n\nRUIN & RECREATE CUSTOMERS\n\n")
    oldcost = compute_cost(instance)
    C = instance.C
    if !at_random
        expensive_c = get_most_expensive_customers(instance)[end]
        recreated_cs = [expensive_c]
        stats["duration_customer_reinsertion"] += @elapsed one_step_ruin_recreate_customer!(instance, expensive_c)
    else
        order = shuffle(collect(1:C))
        stats["duration_customer_reinsertion"] += @elapsed one_step_ruin_recreate_customer!(instance, order[1])
    end
    newcost = compute_cost(instance)
    stats["gain_customer_reinsertion"] += newcost - oldcost
    if compute_total_time(stats) > stats["time_limit"]
        return
    end
    for i = 1:niter-1
        oldcost = newcost
        if !at_random
            expensive_cs = get_most_expensive_customers(instance)
            index = C
            while expensive_cs[index] in recreated_cs && index > 1
                index -= 1
            end
            expensive_c = expensive_cs[index]
            append!(recreated_cs, expensive_c)
            stats["duration_customer_reinsertion"] += @elapsed one_step_ruin_recreate_customer!(instance, expensive_c)
        else 
            stats["duration_customer_reinsertion"] += @elapsed one_step_ruin_recreate_customer!(instance, order[i+1])
        end
        newcost = compute_cost(instance)
        stats["gain_customer_reinsertion"] += newcost - oldcost
        verbose && newcost
        if compute_total_time(stats) > stats["time_limit"]
            return
        end
    end
end

"""
    iterative_ruin_recreate_commodity!(instance::Instance;
                                        niter::Int,
                                        verbose::Bool = false,
                                        stats::Union{Nothing, Dict} = nothing,
                                        sort_by_length::Bool = false,
                                        delete_empty_routes::Bool = true,
    )

Apply [`one_step_ruin_recreate_commodity!`](@ref) `niter` times on commodities.
Two possibilities: select commodities at random, or by decreasing size.
"""
function iterative_ruin_recreate_commodity!(
    instance::Instance;
    niter::Int,
    verbose::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
    sort_by_length::Bool = false,
    delete_empty_routes::Bool = true,
)
    verbose && println("\n\nRUIN & RECREATE COMMODITIES\n\n")
    M = instance.M
    l = [instance.commodities[m].l for m = 1:M]
    if sort_by_length
        order = sortperm(l, rev = true)
    else
        order = shuffle(collect(1:M))
    end
    for commodity_index in order[1:niter]
        oldcost = compute_cost(instance, ms = [commodity_index])
        stats["duration_commodity_reinsertion"] += @elapsed applied = one_step_ruin_recreate_commodity!(
            instance;
            commodity_index = commodity_index,
            integer = true,
            maxdist = Inf,
            delete_empty_routes = delete_empty_routes
        )
        if !applied
            continue
        end
        newcost = compute_cost(instance, ms = [commodity_index])
        stats["gain_commodity_reinsertion"] += newcost - oldcost
        stats["duration_multi_depot_LS"] += @elapsed single_depot_local_search!(
            instance;
            maxdist = Inf,
            verbose = verbose,
            stats = stats,
            in_LNS = true,
        )
        if compute_total_time(stats) > stats["time_limit"]
            return 
        end
    end
end

## ajouter sauvegarde de la meilleure solution courante
"""
    LNS!(instance::Instance;
            tol::Real = 0.01,
            n_it_commodity_reinsertion::Int,
            n_it_customer_reinsertion::Int,
            verbose::Bool = false,
            stats::Union{Nothing, Dict} = nothing,
    )

Large Neighborhood Search applied to `instance`.

Each iteration of the LNS is composed of:
- Multi-depot local search neighborhoods for descent.
- Large neighborhoods: customer and commodity reinsertion, 
    using [`iterative_ruin_recreate_customer!`](@ref) 
    and [`iterative_ruin_recreate_commodity!`](@ref),
    as well as [`refill_routes!`](@ref) MILP-based moves.

The solution process can be stopped when the time elapsed is greater than 
the time limit written in `stats` dictionnary.
"""
function LNS!(
    instance::Instance;
    tol::Real = 0.01,
    n_it_commodity_reinsertion::Int,
    n_it_customer_reinsertion::Int,
    verbose::Bool = false,
    stats::Union{Nothing, Dict} = nothing,
)
    oldcost = compute_cost(instance)
    # we keep the best solution during the LNS
    best_cost = oldcost
    best_solution = mycopy(instance.solution)
    # customer reinsertion steps
    iterative_ruin_recreate_customer!(
        instance,
        niter = n_it_customer_reinsertion,
        verbose = verbose,
        at_random = true,
        stats = stats,
    )
    cost_altered = compute_cost(instance)
    if cost_altered < best_cost
        best_cost = cost_altered
        best_solution = mycopy(instance.solution)
    end
    # commodity reinsertion steps
    iterative_ruin_recreate_commodity!(
        instance,
        niter = n_it_commodity_reinsertion,
        verbose = verbose,
        stats = stats,
    )
    cost_altered = compute_cost(instance)
    if cost_altered < best_cost
        best_cost = cost_altered
        best_solution = mycopy(instance.solution)
    end
    # multi-depot local search 
    stats["duration_multi_depot_LS"] += @elapsed multi_depot_local_search!(
        instance,
        niter = 1,
        verbose = verbose,
        stats = stats,
        in_LNS = true,
    )
    if cost_altered < best_cost
        best_cost = cost_altered
        best_solution = mycopy(instance.solution)
    end
    # refill routes
    refill_iterative_depot!(instance, verbose = verbose, stats = stats)
    cost_altered = compute_cost(instance)
    if cost_altered < best_cost
        best_cost = cost_altered
        best_solution = mycopy(instance.solution)
    end
    newcost = compute_cost(instance)
    stats["nb_iter_LNS"] += 1
    while (newcost - oldcost) / oldcost < -tol
        oldcost = newcost
        # customer reinsertion steps
        iterative_ruin_recreate_customer!(
                instance,
                niter = n_it_customer_reinsertion,
                verbose = verbose,
                at_random = true,
                stats = stats,
            )
        cost_altered = compute_cost(instance)
        if cost_altered < best_cost
            best_cost = cost_altered
            best_solution = mycopy(instance.solution)
        end
        if compute_total_time(stats) > stats["time_limit"]
            break 
        end
        # commodity reinsertion steps
        iterative_ruin_recreate_commodity!(
                instance,
                niter = n_it_commodity_reinsertion,
                verbose = verbose,
                stats = stats,
            )
        cost_altered = compute_cost(instance)
        if cost_altered < best_cost
            best_cost = cost_altered
            best_solution = mycopy(instance.solution)
        end
        if compute_total_time(stats) > stats["time_limit"]
            break 
        end
        # multi-depot local search
        stats["duration_multi_depot_LS"] += @elapsed multi_depot_local_search!(
                instance,
                niter = 1,
                verbose = verbose,
                stats = stats,
                in_LNS = true,
            )
        cost_altered = compute_cost(instance)
        if cost_altered < best_cost
            best_cost = cost_altered
            best_solution = mycopy(instance.solution)
        end
        if compute_total_time(stats) > stats["time_limit"]
            break 
        end
        # refill routes
        refill_iterative_depot!(instance, verbose = verbose, stats = stats)        
        cost_altered = compute_cost(instance)
        if cost_altered < best_cost
            best_cost = cost_altered
            best_solution = mycopy(instance.solution)
        end
        if compute_total_time(stats) > stats["time_limit"]
            stats["nb_iter_LNS"] += 1
            break 
        end
        newcost = compute_cost(instance)
        stats["nb_iter_LNS"] += 1
    end
    # update the solution with the best one found
    instance.solution = best_solution
    update_instance_from_solution!(instance)
end
