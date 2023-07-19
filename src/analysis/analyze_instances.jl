function compute_cumulative_demand(; instance::Instance, m::Int)
    demand_vector = Float64[]
    for customer in instance.customers
        push!(demand_vector, sum(customer.demand[m, :]))
    end
    sort!(demand_vector)
    return cumsum(demand_vector) ./ sum(demand_vector)
end

function compute_cumulative_demand(instance::Instance)
    cumulative_demands = Vector{Float64}[]
    for m in 1:(instance.M)
        push!(cumulative_demands, compute_cumulative_demand(; instance=instance, m=m))
    end
    return cumulative_demands
end

function compute_cumulative_release(; instance::Instance, m::Int)
    release_vector = Float64[]
    for depot in instance.depots
        push!(release_vector, sum(depot.production[m, :]))
    end
    sort!(release_vector)
    return cumsum(release_vector) ./ sum(release_vector)
end

function compute_cumulative_release(instance::Instance)
    cumulative_releases = Vector{Float64}[]
    for m in 1:(instance.M)
        push!(cumulative_releases, compute_cumulative_release(; instance=instance, m=m))
    end
    return cumulative_releases
end

function compute_bin_packing_stats(instance::Instance)
    demand_lengths = zeros(Float64, instance.C, instance.T)
    for c in 1:(instance.C)
        for t in 1:(instance.T)
            demand_lengths[c, t] += sum(
                instance.customers[c].demand[:, t] .*
                [commodity.l for commodity in instance.commodities],
            )
        end
    end
    return demand_lengths ./ instance.vehicle_capacity
end

function analyze_instance(instance::Instance)
    cumulative_releases = compute_cumulative_release(instance)
    cumulative_demands = compute_cumulative_demand(instance)
    bin_packing_stats = compute_bin_packing_stats(instance)
    bin_packing_per_customer = sum(bin_packing_stats; dims=2) ./ instance.T
    bin_packing_per_day = [sum(bin_packing_stats[:, t]) for t in 1:(instance.T)]

    p_release = Plots.plot(
        cumulative_releases;
        title="Cumulative release",
        xlabel="Depot index",
        ylabel="Proportion",
        titlefontsize=20,
        xguidefontsize=18,
        yguidefontsize=18,
        xtickfontsize=18,
        ytickfontsize=18,
        legend=false,
        margin=5 * Plots.mm,
    )
    p_demand = Plots.plot(
        cumulative_demands;
        title="Cumulative demand",
        xlabel="Customer index",
        ylabel="Proportion",
        titlefontsize=20,
        xguidefontsize=18,
        yguidefontsize=18,
        xtickfontsize=18,
        ytickfontsize=18,
        legend=false,
        margin=5 * Plots.mm,
    )

    p_bin_packing_customer = Plots.histogram(
        bin_packing_per_customer;
        nbins=20,
        title="Average daily demand proportion of a vehicle",
        xlabel="Vehicle proportion",
        ylabel="Number of customers",
        alpha=0.5,
        titlefontsize=20,
        xguidefontsize=18,
        yguidefontsize=18,
        xtickfontsize=18,
        ytickfontsize=18,
        legend=false,
        margin=5 * Plots.mm,
    )
    p_bin_packing_day = Plots.bar(
        bin_packing_per_day;
        nbins=instance.T,
        title="Total daily demand proportion of a vehicle",
        xlabel="Day index",
        ylabel="Vehicle proportion",
        alpha=0.5,
        titlefontsize=20,
        xguidefontsize=18,
        yguidefontsize=18,
        xtickfontsize=18,
        ytickfontsize=18,
        legend=false,
        margin=5 * Plots.mm,
    )

    l = @layout [a b; c d]# c; d]
    instance_plot = plot(
        p_release,
        p_demand,
        p_bin_packing_customer,
        p_bin_packing_day;
        layout=l,
        size=(1500, 1000),
    )
    display(instance_plot)
    return savefig(instance_plot, "instance.pdf") # save the fig referenced by plot_ref as filename_string (such as "output.png")
end
