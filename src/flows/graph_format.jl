"""
    FGN

A flow graph node represents a wide array of concepts to define flow graphs.

This structure is a central block of the [`FlowGraph`](@ref) used to build commodity and 
vehicle flow graphs in [`commodity_flow_graph`](@ref) and [`expanded_vehicle_flow_graph`](@ref) for instance.  

# Fields
- `t::Int`: date, by default 0.
- `t_h::Int`: hour (not used in current version), by default 0.
- `d::Int`: depot index, by default 0.
- `c::Int`: customer index, by default 0.
- `s::Int`: stop index, by default 0.
- `str::String`: `string` to mention a concept, by default "?".
"""
struct FGN
    t::Int
    t_h::Int
    d::Int
    c::Int
    s::Int
    str::String
    FGN(; t = 0, t_h = 0, d = 0, c = 0, s = 0, str = "?") = new(t, t_h, d, c, s, str)
end

function Base.hash(fgn::FGN, h::UInt)
    return hash(fgn.t, hash(fgn.t_h, hash(fgn.d, hash(fgn.c, hash(fgn.s, hash(fgn.str, h))))))
end

function Base.isequal(fgn1::FGN, fgn2::FGN)
    return hash(fgn1) == hash(fgn2)
end

"""
    FlowGraph{L}

Flow graph storage with labeled vertices and ordered edges that have capacities and costs.

This structure is used to build commodity and vehicle flow graphs in [`commodity_flow_graph`](@ref)
and [`expanded_vehicle_flow_graph`](@ref) for instance. It is based on the `Graph.jl` package.

# Fields
- `vertexlabels::Vector{L}`: vector of the vertex labels. 
- `vertexindices::Dict{L,Int}`: correspondance between vertex labels and indices.
- `inneighbors::Vector{Vector{Int}}`: one vector of inneighbors indices per vertex index.
- `outneighbors::Vector{Vector{Int}}`: one vector of outneighbors indices per vertex index.
- `edges::Vector{Graphs.SimpleEdge{Int}}`: vector of edges.
- `edgeindices::Dict{Graphs.SimpleEdge{Int},Int}`: correspondance between edges and edgeindices.
- `capa_min::Vector{Float64}`: minimum capacity vector (on edges).
- `capa_max::Vector{Float64}`: maximum capacity vector (on edges).
- `cost::Vector{Float64}`: cost vector (on edges).
"""
mutable struct FlowGraph{L} <: AbstractGraph{Int}
    vertexlabels::Vector{L}
    vertexindices::Dict{L,Int}
    inneighbors::Vector{Vector{Int}}
    outneighbors::Vector{Vector{Int}}
    edges::Vector{Graphs.SimpleEdge{Int}}
    edgeindices::Dict{Graphs.SimpleEdge{Int},Int}
    capa_min::Vector{Float64}
    capa_max::Vector{Float64}
    cost::Vector{Float64}

    function FlowGraph{L}() where {L}
        vertexlabels = L[]
        vertexindices = Dict{L,Int}()
        inneighbors = Vector{Int}[]
        outneighbors = Vector{Int}[]
        edges = Graphs.SimpleEdge{Int}[]
        edgeindices = Dict{Graphs.SimpleEdge{Int},Int}()
        capa_min = Float64[]
        capa_max = Float64[]
        cost = Float64[]
        return new(
            vertexlabels,
            vertexindices,
            inneighbors,
            outneighbors,
            edges,
            edgeindices,
            capa_min,
            capa_max,
            cost,
        )
    end
end

FlowGraph() = FlowGraph{FGN}()

Base.eltype(::FlowGraph) = Int
Graphs.edgetype(::FlowGraph) = Graphs.SimpleEdge{Int}

Graphs.nv(g::FlowGraph) = length(g.vertexlabels)
Graphs.vertices(g::FlowGraph) = 1:nv(g)

Graphs.edges(g::FlowGraph) = g.edges
Graphs.ne(g::FlowGraph) = length(g.edges)

Graphs.has_vertex(g::FlowGraph, v::Int) = 1 <= v <= nv(g)

function Graphs.has_edge(g::FlowGraph, s::Int, d::Int)
    return has_vertex(g, s) && has_vertex(g, t) && d in outneighbors(g, s)
end

Graphs.outneighbors(g::FlowGraph, s::Int) = g.outneighbors[s]
Graphs.inneighbors(g::FlowGraph, d::Int) = g.inneighbors[d]

Graphs.is_directed(g::FlowGraph) = true
Graphs.is_directed(::Type{<:FlowGraph}) = true

get_vertexindex(g::FlowGraph{L}, label::L) where {L} = g.vertexindices[label]
get_vertexlabel(g::FlowGraph, v::Int) = g.vertexlabels[v]

get_edge(g::FlowGraph, edgeindex::Int) = g.edges[edgeindex]

function get_edgeindex(g::FlowGraph, s::Int, d::Int)
    edge = Graphs.SimpleEdge(s, d)
    return g.edgeindices[edge]
end

function get_edgeindex(g::FlowGraph{L}, label1::L, label2::L) where {L}
    s = get_vertexindex(g, label1)
    d = get_vertexindex(g, label2)
    return get_edgeindex(g, s, d)
end

function Graphs.add_vertex!(g::FlowGraph{L}, label::L) where {L}
    push!(g.vertexlabels, label)
    g.vertexindices[label] = length(g.vertexlabels)
    push!(g.inneighbors, Int[])
    push!(g.outneighbors, Int[])
    return true
end

function Graphs.add_edge!(g::FlowGraph, s::Int, d::Int)
    edge = Graphs.SimpleEdge(s, d)
    push!(g.edges, edge)
    g.edgeindices[edge] = length(g.edges)

    push!(g.inneighbors[d], s)
    push!(g.outneighbors[s], d)

    push!(g.capa_min, 0.0)
    push!(g.capa_max, Inf)
    push!(g.cost, 0.0)

    return true
end

function Graphs.add_edge!(g::FlowGraph{L}, label1::L, label2::L) where {L}
    s = get_vertexindex(g, label1)
    d = get_vertexindex(g, label2)
    add_edge!(g, s, d)
end

function set_capa_min!(g::FlowGraph, edgeindex::Int, l::Real)
    g.capa_min[edgeindex] = l
end

function set_capa_max!(g::FlowGraph, edgeindex::Int, u::Real)
    g.capa_max[edgeindex] = u
end

function set_value!(g::FlowGraph, edgeindex::Int, v::Real)
    set_capa_min!(g, edgeindex, v)
    set_capa_max!(g, edgeindex, v)
end

function set_cost!(g::FlowGraph, edgeindex::Int, c::Real)
    g.cost[edgeindex] = c
end

function my_incidence_matrix(g::FlowGraph)
    I = vcat([src(e) for e in edges(g)], [dst(e) for e in edges(g)])
    J = vcat(collect(1:ne(g)), collect(1:ne(g)))
    V = vcat(fill(-1, ne(g)), fill(1, ne(g)))
    return sparse(I, J, V)
end

"""
    add_flow_constraints!(model::Model, flowvar, g::FlowGraph)

Add flow constraints to variable `flowvar` of a JuMP `model`, based on flow graph `g`.

The flow constraints are the following:
- minimum and maximum capacity constraints on all the arcs.
- Kirchhoff constraint for the flow conservation.
"""
function add_flow_constraints!(model::Model, flowvar, g::FlowGraph)
    # Parse edge features
    for k = 1:ne(g)
        capamin, capamax = g.capa_min[k], g.capa_max[k]
        @assert capamin <= capamax
        if capamin == capamax
            fix(flowvar[k], capamin, force = true)
        else
            if capamin > 0.0
                set_lower_bound(flowvar[k], capamin)
            end
            if capamax < Inf
                set_upper_bound(flowvar[k], capamax)
            end
        end
    end
    # Kirchhoff
    @constraint(model, my_incidence_matrix(g) * flowvar .== 0)
end

"""
    add_flow_cost!(expr, flowvar, g::FlowGraph)

Add flow cost of variable `flowvar` to JuMP expression `expr`, based on flow graph `g`.
"""
function add_flow_cost!(expr, flowvar, g::FlowGraph)
    for k = 1:ne(g)
        cost = g.cost[k]
        if cost > 0.0
            add_to_expression!(expr, cost, flowvar[k])
        end
    end
end
