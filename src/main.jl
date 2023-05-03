using Revise
using InventoryRoutingLNS
using BenchmarkTools
using Random
Random.seed!(60)

folder_path = "data/instances/"
list_of_instances = readdir(folder_path)

for instance_id in list_of_instances
    ## Open
    println("Open instance "*instance_id)
    instance = read_instance_CSV("data/instances/"*instance_id)
    ## Solve
    paper_matheuristic!(instance;
        n_it_commodity_reinsertion = 15,
        n_it_customer_reinsertion = 200,
        tol = -0.01,
        time_limit = 90.,
        verbose = true,
    )
end


# Uncomment the following lines to visualize instances and solutions

# folder_path = "data/instances/"
# solutions_path_lns = "data/solutions/LNS_smax3_tl90_co10_cumax/solutions/LNS/"
# solutions_path_initls = "data/solutions/LNS_smax3_tl90_co10_cumax/solutions/init_ls/"
# list_of_instances = readdir(folder_path)

# for instance_id in list_of_instances
#     ## Open instance
#     println("Open instance "*instance_id)
#     instance = read_instance_CSV("data/instances/"*instance_id)
#     ## Open solution 
#     solution_lns = read_solution(solutions_path_lns*instance_id*".txt")
#     solution_init = read_solution(solutions_path_initls*instance_id*".txt")
#     analyze_instance(instance)
#     analyze_solution(instance, solution_lns, solution_init)
#     # compute detailed cost init
#     for route in InventoryRoutingLNS.list_routes(solution_init)
#         push!(instance.solution.routes_per_day_and_depot[route.t, route.d], route)
#     end
#     InventoryRoutingLNS.update_instance_from_solution!(instance)
#     InventoryRoutingLNS.compute_detailed_cost(instance)
#     # compute detailed cost lns 
#     InventoryRoutingLNS.reset_solution!(instance)
#     for route in InventoryRoutingLNS.list_routes(solution_lns)
#         push!(instance.solution.routes_per_day_and_depot[route.t, route.d], route)
#     end
#     InventoryRoutingLNS.update_instance_from_solution!(instance)
#     InventoryRoutingLNS.compute_detailed_cost(instance)
#     break
# end
