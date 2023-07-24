ENV["DATADEPS_ALWAYS_ACCEPT"] = true
using DataDeps
using InventoryRoutingLNS

folder_path = joinpath(datadep"IRP-instances", "instances", "instances")
list_of_instances = readdir(folder_path)

solutions_path_lns = joinpath(
    datadep"IRP-solutions",
    "solutions",
    "solutions",
    "LNS_smax3_tl90_co10_cumax",
    "solutions",
    "LNS",
)
solutions_path_initls = joinpath(
    datadep"IRP-solutions",
    "solutions",
    "solutions",
    "LNS_smax3_tl90_co10_cumax",
    "solutions",
    "init_ls",
)

for instance_id in list_of_instances
    ## Open instance
    println("Open instance " * instance_id)
    instance = read_instance_CSV(joinpath(folder_path, instance_id))
    ## Open solution 
    solution_lns = read_solution(joinpath(solutions_path_lns, instance_id * ".txt"))
    solution_init = read_solution(joinpath(solutions_path_initls, instance_id * ".txt"))
    analyze_instance(instance)
    analyze_solution(instance, solution_lns, solution_init)
    # compute detailed cost init
    for route in InventoryRoutingLNS.list_routes(solution_init)
        push!(instance.solution.routes_per_day_and_depot[route.t, route.d], route)
    end
    InventoryRoutingLNS.update_instance_from_solution!(instance)
    InventoryRoutingLNS.compute_detailed_cost(instance)
    # compute detailed cost lns 
    InventoryRoutingLNS.reset_solution!(instance)
    for route in InventoryRoutingLNS.list_routes(solution_lns)
        push!(instance.solution.routes_per_day_and_depot[route.t, route.d], route)
    end
    InventoryRoutingLNS.update_instance_from_solution!(instance)
    InventoryRoutingLNS.compute_detailed_cost(instance)
end
