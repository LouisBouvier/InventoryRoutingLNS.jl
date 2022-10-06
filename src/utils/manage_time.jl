"""
    compute_total_time(stats::Dict)

Compute the duration in minutes elapsed since the beginning of the solution process.

The dictionnary `stats` stores statistics on the run.
"""
function compute_total_time(stats::Dict)
    duration_fields = ["duration_init_plus_ls", "duration_multi_depot_LS", "duration_customer_reinsertion", "duration_commodity_reinsertion", "duration_refill_routes"]
    return sum(stats[key] for key in duration_fields)/60.0
end
