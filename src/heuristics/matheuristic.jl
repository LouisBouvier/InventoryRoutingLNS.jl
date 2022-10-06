"""
    paper_matheuristic!(instance::Instance;
                    n_it_commodity_reinsertion::Int,
                    n_it_customer_reinsertion::Int, 
                    tol::Float64 = 0.01,
                    time_limit::Float64 = 90.0,
                    verbose::Bool = false,
    )

Solve the instance `instance` with a matheuristic;

The matheuristic consists in:
- two passes of the greedy heuristic, see [`modified_capa_initialization_plus_ls!`](@ref).
- one Large Neighborhood Search defined in [`LNS!`](@ref).

The number of commodity reinsertion per LNS iteration is `n_it_commodity_reinsertion`,
same for `n_it_customer_reinsertion` and customer reinsertion. We can set a time limit 
to the solution process with `time_limit`.
"""
function paper_matheuristic!(instance::Instance;
    n_it_commodity_reinsertion::Int,
    n_it_customer_reinsertion::Int, 
    tol::Float64 = 0.01,
    time_limit::Float64 = 90.0,
    verbose::Bool = false,
)
    # create dict for logs
    stats = Dict()
    stats["tol_LNS"] = tol
    stats["time_limit"] = time_limit
    stats["n_iter_commodity_reinsertion"] = n_it_commodity_reinsertion
    stats["n_it_customer_reinsertion"] = n_it_customer_reinsertion
    stats["nb_iter_LNS"] = 0

    stats["gain_relocate"] = 0
    stats["relocate_applied"] = 0
    stats["relocate_aborted"] = 0

    stats["gain_swap"] = 0
    stats["swap_applied"] = 0
    stats["swap_aborted"] = 0

    stats["gain_two_opt_star"] = 0
    stats["two_opt_star_applied"] = 0
    stats["two_opt_star_aborted"] = 0

    stats["gain_change_day"] = 0
    stats["change_day_applied"] = 0
    stats["change_day_aborted"] = 0

    stats["gain_insert_multi_depot"] = 0
    stats["insert_multi_depot_applied"] = 0
    stats["insert_multi_depot_aborted"] = 0

    stats["gain_swap_multi_depot"] = 0
    stats["swap_multi_depot_applied"] = 0
    stats["swap_multi_depot_aborted"] = 0

    stats["gain_two_opt_star_multi_depot"] = 0
    stats["two_opt_star_multi_depot_applied"] = 0
    stats["two_opt_star_multi_depot_aborted"] = 0

    stats["gain_delete_route"] = 0

    stats["gain_insert_single_depot"] = 0
    stats["insert_single_depot_applied"] = 0
    stats["insert_single_depot_aborted"] = 0

    stats["gain_swap_single_depot"] = 0
    stats["swap_single_depot_applied"] = 0
    stats["swap_single_depot_aborted"] = 0

    stats["gain_merge"] = 0

    stats["gain_merge_multiday"] = 0

    stats["gain_customer_reinsertion"] = 0

    stats["gain_commodity_reinsertion"] = 0

    stats["gain_refill_routes"] = 0

    stats["duration_multi_depot_LS"] = 0
    stats["duration_customer_reinsertion"] = 0
    stats["duration_commodity_reinsertion"] = 0
    stats["duration_refill_routes"] = 0

    # start solving
    # initialization plus local search
    stats["duration_init_plus_ls"] =
        @elapsed modified_capa_initialization_plus_ls!(instance, verbose = verbose, stats = stats)
    cost_after_init_ls, details_init_ls = compute_detailed_cost(instance)
    @assert feasibility(instance, verbose = verbose)
    # large neighborhood search
    LNS!(
        instance,
        tol = tol,
        n_it_commodity_reinsertion = n_it_commodity_reinsertion,
        n_it_customer_reinsertion = n_it_customer_reinsertion,
        verbose = verbose,
        stats = stats,
    )
    @assert feasibility(instance, verbose = verbose)
    cost_after_lns, details_lns = compute_detailed_cost(instance)
    # compute a lower bound
    lb = lower_bound(instance)
    stats["lb"] = lb
    # print results
    verbose && println("\n")
    verbose && println("\n")
    verbose && println("End of the large neighborhood search: \n")
    verbose && println("Lower bound: ", lb)
    verbose && println("Cost after initialization + ls: ", cost_after_init_ls)
    verbose && println("Gap init+ls-LB: ", (cost_after_init_ls - lb) / lb * 100, "% \n")
    verbose && println("Final cost: ", cost_after_lns)
    verbose && println("final gap: ", (cost_after_lns - lb) / lb * 100, "%")
    return stats
end
