"""
    compute_delays(instance::Instance)

Given `instance`, we compute the possible delays for each depot-customer couple.

The possible delays are induced by indirect routes. 
This information is used to build commodity graphs with 
[`commodity_flow_graph`](@ref) to compute a relaxation in [`lower_bound`](@ref).
"""
function compute_delays(instance::Instance)
    D, C = instance.D, instance.C
    transport_durations = instance.transport_durations
    S_max = instance.S_max
    delays_from_depots = Dict()
    @showprogress "Compute possible delays from depots to customers: " for d = 1:D 
        delays = [Set{Int}([transport_durations[d, D + c]]) for c = 1:C]
        delays_to_consider = deepcopy(delays)
        for s = 1:S_max-1
            delays_to_add = [Set{Int}() for c = 1:C]
            for c_dest = 1:C
                for c_source = 1:C
                    for delay in delays_to_consider[c_source]
                        @assert(delay + transport_durations[D + c_source, D + c_dest] >= 0)
                        push!(delays_to_add[c_dest], delay + transport_durations[D + c_source, D + c_dest])
                    end
                end
            end
            for c = 1:C 
                delays_to_consider[c] = setdiff(delays_to_add[c], delays[c])
                delays[c] = union(delays[c], delays_to_add[c])
            end
        end
        delays_from_depots[d] = delays
    end
    # convert to days
    day_delays_from_depots = Dict()
    for d = 1:D 
        day_delays_depot = [Set{Int}() for c = 1:C]
        for c = 1:C
            for delay in delays_from_depots[d][c]
                push!(day_delays_depot[c], floor(delay/instance.nb_transport_hours_per_day))
            end
        end
        day_delays_from_depots[d] = day_delays_depot
    end
    return day_delays_from_depots 
end






