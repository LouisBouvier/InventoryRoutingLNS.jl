"""
    route_based_matheuristic!(instance::Instance;
                            time_limit::Float64,
                            verbose::Bool = true, 
    )                  

Adapt the ideas of recent papers such as [A matheuristic algorithm for the multi-depot inventory routing problem](https://www.sciencedirect.com/science/article/abs/pii/S1366554518307749)
and [A Matheuristic for the Multivehicle Inventory Routing Problem](https://pubsonline.informs.org/doi/10.1287/ijoc.2016.0737) to solve the multi-attribute IRP.

The benchmark works as follows:
- First create an initial solution with the [`modified_capa_initialization_plus_ls!`](@ref) (flows + localsearch)
- Then iteratively solve MILPS with [`refill_iterative_depot!`](@ref) to exploit the routes of the initial solution.

In the original papers one MILP is solved on a larger set of routes and all 
considered at once. Here because of the size of the instances and additional 
structure (multi-depot, multi-commodity, routes that last several days) we 
adapt the ideas solving one MILP per depot (heuristic).
"""
function route_based_matheuristic!(instance::Instance;
                                time_limit::Float64,
                                verbose::Bool = true, 
)                                
    # Statistics on the solution 
    stats = Dict()
    stats["time_limit"] = time_limit

    stats["gain_relocate"] = 0
    stats["relocate_applied"] = 0
    stats["relocate_aborted"] = 0

    stats["gain_swap"] = 0
    stats["swap_applied"] = 0
    stats["swap_aborted"] = 0

    stats["gain_two_opt_star"] = 0
    stats["two_opt_star_applied"] = 0
    stats["two_opt_star_aborted"] = 0

    stats["gain_delete_route"] = 0

    stats["gain_insert_single_depot"] = 0
    stats["insert_single_depot_applied"] = 0
    stats["insert_single_depot_aborted"] = 0

    stats["gain_swap_single_depot"] = 0
    stats["swap_single_depot_applied"] = 0
    stats["swap_single_depot_aborted"] = 0

    stats["gain_merge"] = 0

    stats["gain_merge_multiday"] = 0

    stats["gain_refill_routes"] = 0
    stats["duration_refill_routes"] = 0

    # For time checking
    stats["duration_multi_depot_LS"] = 0
    stats["duration_customer_reinsertion"] = 0
    stats["duration_commodity_reinsertion"] = 0

    # Initial solution with greedy heuristic
    stats["duration_init_plus_ls"] =
        @elapsed modified_capa_initialization_plus_ls!(instance, verbose = verbose, stats = stats)

    cost_after_init_ls, details_init_ls = compute_detailed_cost(instance)
    
    # Refill MILP to solve 
    refill_iterative_depot!(instance; verbose = verbose, stats = stats)

    @assert(feasibility(instance))
    cost_after_refill, details_refill = compute_detailed_cost(instance)
    # compute a lower bound
    lb = lower_bound(instance)
    stats["lb"] = lb

    # print results
    verbose && println("\n")
    verbose && println("\n")
    verbose && println("End of the benchmark, time $(stats["duration_refill_routes"]): \n")
    verbose && println("Lower bound: ", lb)
    verbose && println("Cost after initialization plus ls: ", cost_after_init_ls)
    verbose && println("Gap Init+ls-LB: ", (cost_after_init_ls - lb) / lb * 100, "% \n")
    verbose && println("Final cost: ", cost_after_refill)
    verbose && println("final gap: ", (cost_after_refill - lb) / lb * 100, "%")
    return stats
end
