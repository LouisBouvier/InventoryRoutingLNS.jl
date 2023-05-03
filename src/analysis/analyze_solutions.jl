function compute_solution_stats(instance::Instance, solution::SimpleSolution)
    nb_visit_per_customer = zeros(Int, instance.C)
    nb_departure_per_depot = zeros(Int, instance.D)
    lengths = Int[]
    departure_dates = Int[]
    for route in list_routes(solution)
        nb_departure_per_depot[route.d] += 1
        push!(lengths, length(route.stops))
        push!(departure_dates, route.t)
        for stop in route.stops 
            nb_visit_per_customer[stop.c] += 1 
        end
    end
    return nb_departure_per_depot, nb_visit_per_customer, lengths, departure_dates
end


"""
    analyze_solution(instance::Instance, solution::SimpleSolution)

Compute the number of departures per depot and the number of visit per customer in a solution.
"""
function analyze_solution(instance::Instance, solution_1::SimpleSolution, solution_2::SimpleSolution)
    nb_departure_per_depot_1, nb_visit_per_customer_1, lengths_1, departure_dates_1 = compute_solution_stats(instance, solution_1)
    nb_departure_per_depot_2, nb_visit_per_customer_2, lengths_2, departure_dates_2 = compute_solution_stats(instance, solution_2)

    order_customers = sortperm(nb_visit_per_customer_1)
    nb_visit_per_customer_1 = nb_visit_per_customer_1[order_customers]
    nb_visit_per_customer_2 = nb_visit_per_customer_2[order_customers]
    p_depots = Plots.bar([nb_departure_per_depot_2, nb_departure_per_depot_1], nbins = instance.D, title = "Depots distribution", xlabel = "Depot index", ylabel = "Number of routes", titlefontsize=20, xguidefontsize=18, yguidefontsize=18, xtickfontsize=18,ytickfontsize=18, alpha = 0.8, legend = false, margin = 5*Plots.mm)
    p_dates = Plots.histogram([departure_dates_2, departure_dates_1], nbins = instance.T, title = "Start date distribution", xlabel = "Date index", ylabel = "Number of routes", titlefontsize=20, xguidefontsize=18, yguidefontsize=18, xtickfontsize=18, ytickfontsize=18, alpha = 0.8, legend = false, margin = 5*Plots.mm)
    p_lengths = Plots.histogram([lengths_2, lengths_1], nbins = 10, title = "Route length distribution", xlabel = "Length", ylabel = "Number of routes", titlefontsize=20, xguidefontsize=18, yguidefontsize=18, xtickfontsize=18, ytickfontsize=18, alpha = 0.8, legend = false, margin = 5*Plots.mm)
    p_customers = Plots.bar([nb_visit_per_customer_2, nb_visit_per_customer_1], nbins = instance.C, title = "Customers distribution", xlabel = "Customer index", ylabel = "Number of routes", size = (1500, 500), titlefontsize=20, xguidefontsize=18, yguidefontsize=18, xtickfontsize=18, ytickfontsize=18, legendfontsize=12, alpha = 0.8, labels = ["Initialization + local search" "LNS"], margin = 5*Plots.mm)
    l = @layout [a b c; d]
    solution_plot = plot(p_depots, p_dates, p_lengths, p_customers,  layout = l, size = (1500, 1000))
    display(solution_plot)
    savefig(solution_plot, "solution.pdf") # save the fig referenced by plot_ref as filename_string (such as "output.png")
end

