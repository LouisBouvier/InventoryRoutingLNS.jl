"""
    first_fit_decreasing(items::Vector{IT},
                            weights::Vector{<:Real},
                            W::Real,
    ) where {IT}

Apply FFD bin-packing to (`items`, `weights`) within a container of capacity `W`.
"""
function first_fit_decreasing(
    items::Vector{IT}, weights::Vector{<:Real}, W::Real
) where {IT}
    p = sortperm(weights; rev=true)
    items, weights = items[p], weights[p]
    bin_items = Vector{IT}[]
    bin_weights = Vector{Float64}[]
    push!(bin_items, IT[])
    push!(bin_weights, Float64[])

    for (i, w) in zip(items, weights)
        if sum(bin_weights[end]) + w < W
            push!(bin_items[end], i)
            push!(bin_weights[end], w)
        else
            push!(bin_items, [i])
            push!(bin_weights, [w])
        end
    end
    return bin_items
end

"""
    bin_packing_milp(items::Vector{IT}, weights::Vector{<:Real}, W::Real) where {IT}

Apply exact bin-packing to (`items`, `weights`) within a container of capacity `W`.

Solve a MILP.
"""
function bin_packing_milp(items::Vector{IT}, weights::Vector{<:Real}, W::Real) where {IT}
    n = length(items)
    B = length(first_fit_decreasing(items, weights, W))

    model = Model(Gurobi.Optimizer)
    @variable(model, x[1:n, 1:B], Bin)
    @variable(model, y[1:B], Bin)

    for i in 1:n
        @constraint(model, sum(model[:x][i, :]) == 1)
    end
    for b in 1:B
        @constraint(model, W * model[:y][b] >= sum(model[:x][:, b] .* weights))
    end

    @objective(model, Min, sum(model[:y]))

    optimize!(model)

    yval = value.(model[:y])
    xval = value.(model[:x])

    bin_items = Vector{Vector{IT}}(undef, B)
    for b in 1:B
        bin_items[b] = IT[]
        for i in 1:n
            if xval[i, b] == 1
                push!(bin_items[b], items[i])
            end
        end
    end
    return [bin for bin in bin_items if length(bin) > 0]
end
