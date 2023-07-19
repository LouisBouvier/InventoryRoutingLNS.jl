## Encoding in a string
"""
    Base.string(commodity::Commodity)::String

Encode `commodity` in a `string`.
"""
function Base.string(commodity::Commodity)::String
    str = "m $(commodity.m - 1) l $(commodity.l)"
    return str
end

"""
    Base.string(depot::Depot)::String

Encode `depot` in a `string`.
"""
function Base.string(depot::Depot)::String
    M, T = size(depot.production)
    str = "d $(depot.d - 1) v $(depot.v - 1) coor $(depot.coordinates[1]) $(depot.coordinates[2]) "
    str *= "cm "
    for m in 1:M
        str *= "m $(m - 1) cr $(depot.excess_inventory_cost[m]) b $(depot.initial_inventory[m]) "
    end
    str *= "pro "
    for t in 1:T
        str *= "t $(t - 1) "
        for m in 1:M
            str *= "m $(m - 1) b $(depot.production[m, t]) r $(depot.maximum_inventory[m, t]) "
        end
    end
    return str[1:(end - 1)]
end

"""
    Base.string(customer::Customer)::String

Encode `customer` in a `string`.
"""
function Base.string(customer::Customer)::String
    M, T = size(customer.demand)
    str = "c $(customer.c - 1) v $(customer.v - 1) coor $(customer.coordinates[1]) $(customer.coordinates[2]) "
    str *= "cm "
    for m in 1:M
        str *= "m $(m - 1) cr $(customer.excess_inventory_cost[m]) cexc $(customer.shortage_cost[m]) b $(customer.initial_inventory[m]) "
    end
    str *= "dem "
    for t in 1:T
        str *= "t $(t - 1) "
        for m in 1:M
            str *= "m $(m - 1) b $(customer.demand[m, t]) r $(customer.maximum_inventory[m, t]) "
        end
    end
    return str[1:(end - 1)]
end

"""
    Distances

Store the site-to-site distances. 

# Fields
- `dist::Matrix{Int}`: distances matrix (km).
"""
struct Distances
    dist::Matrix{Int}
    Distances(; dist) = new(dist)
end

"""
    Base.string(distances::Distances)::String

Encode site-to-site `distances` in a `string`.
"""
function Base.string(distances::Distances)::String
    V = size(distances.dist, 1)
    str = ""
    for u in 1:V, v in 1:V
        str *= "a $(u - 1) $(v - 1) d $(distances.dist[u, v])\n"
    end
    return str[1:(end - 1)]
end

"""
    Base.string(stop::RouteStop)::String

Encode route `stop` in a `string`.
"""
function Base.string(stop::RouteStop)::String
    M = length(stop.Q)
    str = "c $(stop.c - 1) t $(stop.t - 1)"
    for m in 1:M
        str *= " m $(m - 1) q $(stop.Q[m])"
    end
    return str
end

"""
    Base.string(route::Route, r::Int)::String

Encode `route` in a `string`.
"""
function Base.string(route::Route, r::Int)::String
    t = route.t
    d = route.d
    C = length(route.stops)
    str = "r $(r - 1) t $(t - 1) d $(d - 1) C $C"
    for stop in route.stops
        str *= " " * string(stop)
    end
    return str
end

## Export in a file
"""
    write_instance(instance::Instance, path::String)

Encode `instance` in a text file at `path` location.
"""
function write_instance(instance::Instance, path::String)
    T, D, C, M = instance.T, instance.D, instance.C, instance.M
    vehicle_capacity, km_cost, vehicle_cost, stop_cost = instance.vehicle_capacity,
    instance.km_cost, instance.vehicle_cost,
    instance.stop_cost
    nb_transport_hours_per_day = instance.nb_transport_hours_per_day
    vehicle_speed = 50 ## to adapt the former format of instances 
    str = "T $T D $D C $C M $M L $vehicle_capacity Gamma $km_cost CVeh $vehicle_cost CStop $stop_cost HpD $nb_transport_hours_per_day VS $vehicle_speed\n"

    for commodity in instance.commodities
        str *= string(commodity) * "\n"
    end
    for depot in instance.depots
        str *= string(depot) * "\n"
    end
    for customer in instance.customers
        str *= string(customer) * "\n"
    end
    str *= string(Distances(; dist=instance.dist)) * "\n"
    open(path, "w") do file
        write(file, str)
    end
end

"""
    write_solution(solution::Solution, path::String)

Encode `solution` in a file at `path` location.
"""
function write_solution(solution::Solution, path::String)
    R = nb_routes(solution)
    str = "R $R"
    for (r, route) in enumerate(list_routes(solution))
        str *= "\n" * string(route, r)
    end
    open(path, "w") do file
        write(file, str)
    end
    return true
end

"""
    write_solution(instance::Instance, path::String)

Encode the solution stored in `instance` in a file at `path` location.
"""
write_solution(instance::Instance, path::String) = write_solution(instance.solution, path)

## write the lower bounds in a file
"""
    write_lower_bounds(path_to_folder::String, rescale::Bool)

Compute and write all the lower bounds on the IRP instances contained in a folder.

We possibly rescale instances with [`rescale_release_demand!`](@ref).
The lower bounds are computed with the flow relaxation [`lower_bound`](@ref).
"""
function write_lower_bounds(path_to_folder::String, rescale::Bool)
    list_of_instances = readdir(path_to_folder)
    dict_lb = Dict()
    for instance_name in list_of_instances
        # try
        println(instance_name)
        instance = read_instance_CSV(joinpath(path_to_folder, instance_name))
        if rescale
            rescale_release_demand!(instance)
        end
        if feasibility(instance)
            lb = lower_bound(instance)
            dict_lb[instance_name] = lb
            println(lb)
        else
            dict_lb[instance_name] = -1
        end
        # catch
        #     continue
        # end
    end
    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(dict_lb)
    # write the file with the stringdata variable information
    open("lower_bounds.json", "w") do f
        write(f, stringdata)
    end
end

"""
    write_stats(; stats::Dict = nothing, path_to_folder::String)

Write the `stats` of the solution process in a `JSON` file for analysis.

The stats are computed during optimization and defined in [`paper_matheuristic!`](@ref).
"""
function write_stats(; stats::Dict=nothing, path_to_folder::String)
    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(stats)
    # write the file with the stringdata variable information
    open(path_to_folder * "stats_resolution.json", "w") do f
        write(f, stringdata)
    end
end

"""
    write_detailed_cost(; cost_dict, path_to_folder::String, name::String)

Write a detailed cost in a `JSON` file.

The detailed cost is studied at various steps of [`paper_matheuristic!`](@ref).
"""
function write_detailed_cost(; cost_dict, path_to_folder::String, name::String)
    # pass data as a json string (how it shall be displayed in a file)
    stringdata = JSON.json(cost_dict)
    # write the file with the stringdata variable information

    open(path_to_folder * name * ".json", "w") do f
        write(f, stringdata)
    end
end

# function write_rescaled_instance(;rescaled_instance::Instance, instance_path::String)
#     _, commodities_names = read_commodities_CSV(instance_path)
#     ## get the codes
#     depots_codes = DataFrame(CSV.File(joinpath(instance_path, "depots_codes.csv")))[!, "code"]
#     for depot_code in depots_codes
#         ## global
#         path_to_depot_folder = joinpath(instance_path, "depot_" * string(depot_code))
#         df_depot_global = DataFrame(CSV.File(joinpath(path_to_depot_folder, "global.csv")))
#         d = df_depot_global[!, "d"][1]
#         v = df_depot_global[!, "v"][1]
#         @assert(d == v)
#         depot_rescaled = rescaled_instance.depots[d+1]
#         ## per day and commodity
#         df_production = DataFrame(CSV.File(joinpath(path_to_depot_folder, "release.csv")))
#         @assert(df_production.commodity_code == commodities_names)
#         df_production[:, Not("commodity_code")] = depot_rescaled.production        
#         df_max_inventory =
#             DataFrame(CSV.File(joinpath(path_to_depot_folder, "maximum_stock.csv")))
#         df_max_inventory[:,  Not("commodity_code")] = depot_rescaled.maximum_inventory
#         @assert(names(df_production) == names(df_max_inventory)) ## we could check the order in addition
#         ## rewrite CSV 
#         CSV.write(joinpath(path_to_depot_folder, "release.csv"), df_production)
#         CSV.write(joinpath(path_to_depot_folder, "maximum_stock.csv"), df_max_inventory)
#     end
# end
