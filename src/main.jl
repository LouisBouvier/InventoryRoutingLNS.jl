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

