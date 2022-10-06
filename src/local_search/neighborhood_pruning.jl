"""
    get_neighbors_from_list(instance::Instance,
                            c::Int,
                            cs::Vector{Int},
                            prop::Float64,
    )::Vector{Int}

Select the `prop` proportion of the closest neighbors to a customer `c` among customers `cs`.
"""
function get_neighbors_from_list(
    instance::Instance,
    c::Int,
    cs::Vector{Int},
    prop::Float64,
)::Vector{Int}
    D, dist = instance.D, instance.dist
    distances_c_cs = [dist[D+c, D+c_n] for c_n in cs]
    ranks_cs = sortperm(distances_c_cs)
    selected_indices = ranks_cs[1:Int(floor(length(ranks_cs) * prop))]
    return cs[selected_indices]
end
