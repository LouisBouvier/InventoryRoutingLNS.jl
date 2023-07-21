"""
    solve_flows_initial_solution(instance::Instance; optimizer, average_content_sizes::Union{Nothing,AverageContentSizes} = nothing)

Define and solve the initial flow problems to decide the quantities to send.

From the quantities we solve bin packing problems 
and apply localsearch in  [`initialization_plus_ls!`](@ref).
"""
function solve_flows_initial_solution(
    instance::Instance;
    optimizer,
    average_content_sizes::Union{Nothing,AverageContentSizes}=nothing,
)
    D, C, T, M = instance.D, instance.C, instance.T, instance.M

    fgs_commodities = Vector{FlowGraph}(undef, M)
    values = Vector{Int}(undef, M)
    flows = Vector{Vector{Float64}}(undef, M)
    @showprogress "Solve one flow problem per commodity:" for m in 1:M
        fg_commodity = commodity_flow_graph(
            instance;
            commodity_index=m,
            S_max=1,
            maxdist=Inf,
            relaxed_trip_cost=true,
            average_content_sizes=average_content_sizes,
            force_routes_values=false,
            sent_quantities_to_force=zeros(1),
            sparsify=true,
            set_upper_capa=false,
        )
        # end

        fgs_commodities[m] = fg_commodity

        model = Model(optimizer)
        @variable(model, x[1:ne(fg_commodity)] >= 0)

        add_flow_constraints!(model, model[:x], fg_commodity)
        expr = AffExpr(0.0)
        add_flow_cost!(expr, model[:x], fg_commodity)
        @objective(model, Min, expr)

        if optimizer === Gurobi.Optimizer
            set_optimizer_attribute(model, "OutputFlag", 0)
            set_optimizer_attribute(model, "Method", 1)
        elseif optimizer === HiGHS.Optimizer
            set_optimizer_attribute(model, "output_flag", false)
            set_optimizer_attribute(model, "solver", "simplex")
            set_optimizer_attribute(model, "simplex_strategy", 1)
        end
        optimize!(model)
        @assert termination_status(model) == MOI.OPTIMAL

        values[m] = ceil(Int, objective_value(model))
        flows[m] = value.(model[:x])
    end

    value_of_flows = sum(values)
    sent_quantities = zeros(Int, M, D, C, T)

    for m in 1:M
        fg_commodity = fgs_commodities[m]
        for (k, edge) in enumerate(edges(fg_commodity))
            n1 = get_vertexlabel(fg_commodity, src(edge))
            n2 = get_vertexlabel(fg_commodity, dst(edge))
            if n1.d > 0 && n2.c > 0
                t = n1.t
                d, c = n1.d, n2.c
                flow_int = round(Int, flows[m][k])
                @assert abs(flows[m][k] - flow_int) < 1e-5
                sent_quantities[m, d, c, t] += flow_int
            end
        end
    end

    return value_of_flows, sent_quantities
end

"""
    lower_bound(instance::Instance; optimizer)

Define and solve the initial flow relaxation problem on `instance`.

This relaxation implies the computation of possible delays 
to create direct delayed arcs in the commodity flow graphs.
See [`compute_delays`](@ref) for the delay computation, 
and [`commodity_flow_graph`](@ref)for the impact on the commodity graphs.
"""
function lower_bound(instance::Instance; optimizer)
    M = instance.M
    fgs_commodities = Vector{FlowGraph}(undef, M)
    values = Vector{Int}(undef, M)

    # precompute possible delays
    possible_delays = compute_delays(instance)

    @showprogress "Solve one flow problem per commodity:" for m in 1:M
        fg_commodity = commodity_flow_graph(
            instance;
            commodity_index=m,
            S_max=1,
            maxdist=Inf,
            relaxed_trip_cost=true,
            average_content_sizes=nothing,
            force_routes_values=false,
            sent_quantities_to_force=zeros(1),
            sparsify=true,
            set_upper_capa=false,
            possible_delays=possible_delays,
            add_delayed_arcs=true,
        )

        fgs_commodities[m] = fg_commodity

        model = Model(optimizer)
        @variable(model, x[1:ne(fg_commodity)] >= 0)

        add_flow_constraints!(model, model[:x], fg_commodity)
        expr = AffExpr(0.0)
        add_flow_cost!(expr, model[:x], fg_commodity)
        @objective(model, Min, expr)

        if optimizer === Gurobi.Optimizer
            set_optimizer_attribute(model, "OutputFlag", 0)
            set_optimizer_attribute(model, "Method", 1)
        elseif optimizer === HiGHS.Optimizer
            set_optimizer_attribute(model, "output_flag", false)
            set_optimizer_attribute(model, "solver", "simplex")
            set_optimizer_attribute(model, "simplex_strategy", 1)
        end
        optimize!(model)
        @assert termination_status(model) == MOI.OPTIMAL

        values[m] = ceil(Int, objective_value(model))
    end

    value_of_flows = sum(values)
    return value_of_flows
end
