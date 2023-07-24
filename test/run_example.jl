ENV["DATADEPS_ALWAYS_ACCEPT"] = true

using DataDeps
using InventoryRoutingLNS
using Random
Random.seed!(60)

folder_path = joinpath(datadep"IRP-instances", "instances", "instances")
list_of_instances = readdir(folder_path)

for instance_id in list_of_instances
    println("Reading instance $instance_id")
    instance = read_instance_CSV(joinpath(folder_path, instance_id))
end

let instance_id = list_of_instances[1]
    println("Solving instance $instance_id")
    instance = read_instance_CSV(joinpath(folder_path, list_of_instances[1]))
    paper_matheuristic!(
        instance;
        n_it_commodity_reinsertion=3,
        n_it_customer_reinsertion=3,
        tol=-0.01,
        time_limit=5.0,
        verbose=true,
    )
end
