function heap_transpositions!(acc::Vector{Tuple{Int,Int}}, k::Int)
    if k == 1
        return nothing
    else
        heap_transpositions!(acc, k - 1)
        for i in 1:(k - 1)
            if k % 2 == 0
                push!(acc, (i, k))
            else
                push!(acc, (1, k))
            end
            heap_transpositions!(acc, k - 1)
        end
    end
end

"""
    heap_transpositions(k::Int)

List the transpositions necessary to enumerate all permutations of `1:k`.

Lightweight implementation of Heap's algorithm.
"""
function heap_transpositions(k::Int)
    acc = Tuple{Int,Int}[]
    heap_transpositions!(acc, k)
    return acc
end

"""
    heap_permutations!(a)

Enumerate all permutations of `a` in-place and print them.
"""
function heap_permutations!(a)
    println(a)
    counter = 1
    for (i, j) in heap_transpositions(length(a))
        a[i], a[j] = a[j], a[i]
        println(a)
        counter += 1
    end
    return println(counter)
end

"""
    HEAP_TRANSPOSITIONS
    
Constant list the transpositions necessary to enumerate all permutations of `1:k`.

Computed for `k in 1:4` only.
"""
const HEAP_TRANSPOSITIONS = [heap_transpositions(k) for k in 1:4]
