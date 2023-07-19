"""
    Solution

Abstract IRP solution.

A solution gathers routes in different ways.
See [`SimpleSolution`](@ref) or [`StructuredSolution`](@ref).
"""
abstract type Solution end

"""
    Base.show(io::IO, solution::Solution)

Display `solution`.
"""
function Base.show(io::IO, solution::Solution)
    routes = list_routes(solution)
    R = length(routes)
    str = "IRP solution with $R route(s)"
    return println(io, str)
end
