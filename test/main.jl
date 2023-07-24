using DataDeps
using Gurobi
using InventoryRoutingLNS
using Random
Random.seed!(60)

folder_path = joinpath(datadep"IRP-instances", "instances", "instances")
list_of_instances = readdir(folder_path)


for instance_id in list_of_instances
    println("Solving instance $instance_id")
    instance = read_instance_CSV(joinpath(folder_path, instance_id))
    paper_matheuristic!(
        instance;
        n_it_commodity_reinsertion=10,
        n_it_customer_reinsertion=instance.C,
        tol=-0.01,
        time_limit=90.0,
        verbose=true,
        optimizer = Gurobi.Optimizer
    )
end
