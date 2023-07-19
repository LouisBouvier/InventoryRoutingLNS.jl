## Instance dimensions
"""
    read_dimensions(row::String)::NamedTuple

Read the global data of an instance from a text file.
"""
function read_dimensions(row::String)::NamedTuple
    row_split = split(row, r"\s+")
    return (
        T=parse(Int, row_split[2]),
        D=parse(Int, row_split[4]),
        C=parse(Int, row_split[6]),
        M=parse(Int, row_split[8]),
        vehicle_capacity=parse(Int, row_split[10]),
        km_cost=parse(Int, row_split[12]),
        vehicle_cost=parse(Int, row_split[14]),
        stop_cost=parse(Int, row_split[16]),
        nb_transport_hours_per_day=parse(Int, row_split[18]),
        vehicle_speed=parse(Int, row_split[20]),
    )
end

## Commodities
"""
    read_commodity(row::String, dims::NamedTuple)::Commodity

Create a `commodity` from a row of a text file.
"""
function read_commodity(row::String, dims::NamedTuple)::Commodity
    row_split = split(row, r"\s+")
    m = parse(Int, row_split[2]) + 1
    l = parse(Int, row_split[4])
    return Commodity(; m=m, l=l)
end

## Depots
"""
    read_depot(row::String, dims::NamedTuple)::Depot

Create a `depot` from a text file.
"""
function read_depot(row::String, dims::NamedTuple)::Depot
    row_split = split(row, r"\s+")
    d = parse(Int, row_split[2]) + 1
    v = parse(Int, row_split[4]) + 1
    coordinates = (parse(Float64, row_split[6]), parse(Float64, row_split[7])) # .+ 1e-2*rand()
    k = 8

    excess_inventory_cost = Vector{Int}(undef, dims.M)
    initial_inventory = Vector{Int}(undef, dims.M)

    k += 1
    for m in 1:(dims.M)
        excess_inventory_cost[m] = parse(Int, row_split[k + 3])
        initial_inventory[m] = parse(Int, row_split[k + 5])
        k += 6
    end

    production = Matrix{Int}(undef, dims.M, dims.T)
    maximum_inventory = Matrix{Int}(undef, dims.M, dims.T)

    k += 1
    for t in 1:(dims.T)
        k += 2
        for m in 1:(dims.M)
            production[m, t] = parse(Int, row_split[k + 3])
            maximum_inventory[m, t] = parse(Int, row_split[k + 5])
            k += 6
        end
    end

    return Depot(;
        d=d,
        v=v,
        coordinates=coordinates,
        excess_inventory_cost=excess_inventory_cost,
        initial_inventory=initial_inventory,
        production=production,
        maximum_inventory=maximum_inventory,
    )
end

## Customers
"""
    read_customer(row::String, dims::NamedTuple)::Customer

Create a `customer` from a text file.
"""
function read_customer(row::String, dims::NamedTuple)::Customer
    row_split = split(row, r"\s+")
    c = parse(Int, row_split[2]) + 1
    v = parse(Int, row_split[4]) + 1
    coordinates = (parse(Float64, row_split[6]), parse(Float64, row_split[7])) # .+ 1e-2*rand()
    k = 8

    excess_inventory_cost = Vector{Int}(undef, dims.M)
    shortage_cost = Vector{Int}(undef, dims.M)
    initial_inventory = Vector{Int}(undef, dims.M)

    k += 1
    for m in 1:(dims.M)
        excess_inventory_cost[m] = parse(Int, row_split[k + 3])
        shortage_cost[m] = parse(Int, row_split[k + 5])
        initial_inventory[m] = parse(Int, row_split[k + 7])
        k += 8
    end

    demand = Matrix{Int}(undef, dims.M, dims.T)
    maximum_inventory = Matrix{Int}(undef, dims.M, dims.T)

    k += 1
    for t in 1:(dims.T)
        k += 2
        for m in 1:(dims.M)
            demand[m, t] = parse(Int, row_split[k + 3])
            maximum_inventory[m, t] = parse(Int, row_split[k + 5])
            k += 6
        end
    end

    return Customer(;
        c=c,
        v=v,
        coordinates=coordinates,
        excess_inventory_cost=excess_inventory_cost,
        shortage_cost=shortage_cost,
        initial_inventory=initial_inventory,
        demand=demand,
        maximum_inventory=maximum_inventory,
    )
end

## Distances
"""
    read_distances(rows::Vector{String}, dims::NamedTuple)::Matrix{Int}

Get the distances `matrix` from a text file.
"""
function read_distances(rows::Vector{String}, dims::NamedTuple)::Matrix{Int}
    dist = zeros(Int, dims.D + dims.C, dims.D + dims.C)
    for row in rows
        row_split = split(row, r"\s+")
        v1 = parse(Int, row_split[2]) + 1
        v2 = parse(Int, row_split[3]) + 1
        distance = parse(Int, row_split[5])
        dist[v1, v2] = distance
    end
    return dist
end

## Transport durations between sites 
"""
    read_transport_durations(rows::Vector{String}, dims::NamedTuple)::Matrix{Int}

Get the transport durations `matrix` from a distances text file.

We assume a constant speed model here.
"""
function read_transport_durations(rows::Vector{String}, dims::NamedTuple)::Matrix{Int}
    durations = zeros(Int, dims.D + dims.C, dims.D + dims.C)
    vehicle_speed = dims.vehicle_speed
    for row in rows
        row_split = split(row, r"\s+")
        v1 = parse(Int, row_split[2]) + 1
        v2 = parse(Int, row_split[3]) + 1
        distance = parse(Int, row_split[5])
        durations[v1, v2] = ceil(distance / vehicle_speed)
    end
    return durations
end

## Route
"""
    read_route(row::String)::Route

Create a `route` from a row of a text file.
"""
function read_route(row::String)::Route
    row_split = split(row, r"\s+")
    t = parse(Int, row_split[4]) + 1
    d = parse(Int, row_split[6]) + 1

    stops = RouteStop[]

    k = 9
    while k <= length(row_split)
        c = parse(Int, row_split[k + 1]) + 1
        k += 2

        t_c = parse(Int, row_split[k + 1]) + 1
        k += 2

        Q = Int[]
        while (k <= length(row_split)) && (row_split[k] == "m")
            push!(Q, parse(Int, row_split[k + 3]))
            k += 4
        end
        push!(stops, RouteStop(; c=c, t=t_c, Q=Q))
    end

    return Route(; t=t, d=d, stops=stops)
end

## Whole instance
"""
    read_instance(path::String)::Instance

Create a whole `instance` from a text file.

This function is only used on the KIRO instances (smaller
and used for tests). Real instances are read from CSV files, 
see [`read_instance_CSV`](@ref). 
"""
function read_instance(path::String)::Instance
    data = open(path) do file
        readlines(file)
    end

    dims = read_dimensions(data[1])
    commodities = [read_commodity(data[1 + m], dims) for m in 1:(dims.M)]
    depots = [read_depot(data[1 + dims.M + d], dims) for d in 1:(dims.D)]
    customers = [read_customer(data[1 + dims.M + dims.D + c], dims) for c in 1:(dims.C)]
    dist = read_distances(data[(1 + dims.M + dims.D + dims.C + 1):end], dims)
    transport_durations = read_transport_durations(
        data[(1 + dims.M + dims.D + dims.C + 1):end], dims
    )

    return Instance(;
        T=dims.T,
        D=dims.D,
        C=dims.C,
        M=dims.M,
        vehicle_capacity=dims.vehicle_capacity,
        km_cost=dims.km_cost,
        vehicle_cost=dims.vehicle_cost,
        stop_cost=dims.stop_cost,
        nb_transport_hours_per_day=dims.nb_transport_hours_per_day,
        S_max=3,
        commodities=commodities,
        depots=depots,
        customers=customers,
        dist=dist,
        transport_durations=transport_durations,
        solution=StructuredSolution(dims.T, dims.D),
    )
end

## Solution
"""
    read_solution(path::String)::SimpleSolution

Create a simple `solution` from a text file.
"""
function read_solution(path::String)::SimpleSolution
    sol = open(path) do file
        readlines(file)
    end
    R = parse(Int, split(sol[1], r"\s+")[2])
    routes = [read_route(sol[1 + r]) for r in 1:R]
    return SimpleSolution(routes)
end

## from CSV files ##
"""
    read_dimensions_CSV(path::String)::NamedTuple

Read the global data of an `instance` from a `CSV` file.
"""
function read_dimensions_CSV(path::String)::NamedTuple
    df_global_constants = DataFrame(CSV.File(joinpath(path, "general_constants.csv")))
    return (
        T=df_global_constants[!, "T"][1],
        D=df_global_constants[!, "D"][1],
        C=df_global_constants[!, "C"][1],
        M=df_global_constants[!, "M"][1],
        vehicle_capacity=df_global_constants[!, "vehicle_capacity"][1],
        km_cost=df_global_constants[!, "km_cost"][1],
        vehicle_cost=df_global_constants[!, "vehicle_cost"][1],
        stop_cost=df_global_constants[!, "stop_cost"][1],
        nb_transport_hours_per_day=df_global_constants[!, "nb_transport_hours_per_day"][1],
    )
end

"""
    read_commodities_CSV(path::String)

Create a vector of commodities from a `CSV` file.
"""
function read_commodities_CSV(path::String)
    df_commodities_lengths = DataFrame(CSV.File(joinpath(path, "commodity_lengths.csv")))
    names = Vector{String}(df_commodities_lengths[!, "commodity_code"])
    lengths = df_commodities_lengths[!, "length"]
    return [Commodity(; m=m, l=lengths[m]) for m in 1:length(lengths)], names
end

"""
    read_depots_CSV(path::String, dims::NamedTuple, commodity_codes::Vector{String})

Create a vector of depots from `CSV` files.

In each depot folder, there is one master data file, one file on maximum stock 
per commodity and per day, one file for the release per commodity and day, 
and one file for the initial inventory and unit excess inventory cost per commodity. 
All of them are `CSV` files that can be easily converted into arrays.
"""
function read_depots_CSV(path::String, dims::NamedTuple, commodity_codes::Vector{String})
    depots = Vector{Depot}(undef, dims.D)
    v_index_to_code = Vector{Int}(undef, dims.D + dims.C)
    ## get the codes
    depots_codes = DataFrame(CSV.File(joinpath(path, "depots_codes.csv")))[!, "code"]
    for depot_code in depots_codes
        ## global
        path_to_depot_folder = joinpath(path, "depot_" * string(depot_code))
        df_depot_global = DataFrame(CSV.File(joinpath(path_to_depot_folder, "global.csv")))
        d = df_depot_global[!, "d"][1]
        v = df_depot_global[!, "v"][1]
        @assert(d == v)
        coordinates = (
            df_depot_global[!, "latitude"][1], df_depot_global[!, "longitude"][1]
        )

        ## per commodity
        df_per_commodity = DataFrame(
            CSV.File(joinpath(path_to_depot_folder, "per_commodity.csv"))
        )
        excess_inventory_cost = Vector{Int}(undef, dims.M)
        initial_inventory = Vector{Int}(undef, dims.M)
        @assert(commodity_codes == df_per_commodity.commodity_code)
        for m in 1:length(commodity_codes)
            excess_inventory_cost[m] = df_per_commodity[!, "excess_inventory_cost"][m]
            initial_inventory[m] = df_per_commodity[!, "initial_inventory"][m]
        end

        ## per day and commodity
        df_production = DataFrame(CSV.File(joinpath(path_to_depot_folder, "release.csv")))
        @assert(df_production.commodity_code == commodity_codes)
        production = Matrix(select!(df_production, Not(:commodity_code)))
        df_max_inventory = DataFrame(
            CSV.File(joinpath(path_to_depot_folder, "maximum_stock.csv"))
        )
        maximum_inventory = Matrix(select!(df_max_inventory, Not(:commodity_code)))
        @assert(names(df_production) == names(df_max_inventory)) ## we could check the order in addition

        ## update the lists
        depots[d + 1] = Depot(;
            d=d + 1,
            v=v + 1,
            coordinates=coordinates,
            excess_inventory_cost=excess_inventory_cost,
            initial_inventory=initial_inventory,
            production=production,
            maximum_inventory=maximum_inventory,
        )
        v_index_to_code[v + 1] = Int(depot_code)
    end
    return depots, v_index_to_code
end

"""
    read_customers_CSV(path::String,
                        dims::NamedTuple,
                        commodity_codes::Vector{String},
                        v_index_to_code::Vector{Int},
    )

Create a vector of customers from `CSV` files.

In each customer folder, there is one master data file, one file on maximum stock 
per commodity and per day, one file for the demand per commodity and day, 
and one file for the initial inventory, unit excess and unit shortage cost per commodity. 
All of them are `CSV` files that can be easily converted into arrays.
"""
function read_customers_CSV(
    path::String,
    dims::NamedTuple,
    commodity_codes::Vector{String},
    v_index_to_code::Vector{Int},
)
    customers = Vector{Customer}(undef, dims.C)
    ## get the codes
    customer_codes = DataFrame(CSV.File(joinpath(path, "customers_codes.csv")))[!, "code"]
    for customer_code in customer_codes
        ## global
        path_to_customer_folder = joinpath(path, "customer_" * string(customer_code))
        df_customer_global = DataFrame(
            CSV.File(joinpath(path_to_customer_folder, "global.csv"))
        )
        c = df_customer_global[!, "c"][1]
        v = df_customer_global[!, "v"][1]
        @assert(c + dims.D == v)
        coordinates = (
            df_customer_global[!, "latitude"][1], df_customer_global[!, "longitude"][1]
        )

        ## per commodity
        df_per_commodity = DataFrame(
            CSV.File(joinpath(path_to_customer_folder, "per_commodity.csv"))
        )
        excess_inventory_cost = Vector{Int}(undef, dims.M)
        initial_inventory = Vector{Int}(undef, dims.M)
        shortage_cost = Vector{Int}(undef, dims.M)
        @assert(commodity_codes == df_per_commodity.commodity_code)

        for m in 1:length(commodity_codes)
            excess_inventory_cost[m] = df_per_commodity[!, "excess_inventory_cost"][m]
            initial_inventory[m] = df_per_commodity[!, "initial_inventory"][m]
            shortage_cost[m] = df_per_commodity[!, "shortage_cost"][m]
        end

        ## per day and commodity
        df_demand = DataFrame(CSV.File(joinpath(path_to_customer_folder, "demand.csv")))
        @assert(df_demand.commodity_code == commodity_codes)
        demand = Matrix(select!(df_demand, Not(:commodity_code)))
        df_max_inventory = DataFrame(
            CSV.File(joinpath(path_to_customer_folder, "maximum_stock.csv"))
        )
        maximum_inventory = Matrix(select!(df_max_inventory, Not(:commodity_code)))
        @assert(names(df_demand) == names(df_max_inventory)) ## we could check the order in addition

        ## update the lists
        customers[c + 1] = Customer(;
            c=c + 1,
            v=v + 1,
            coordinates=coordinates,
            excess_inventory_cost=excess_inventory_cost,
            shortage_cost=shortage_cost,
            initial_inventory=initial_inventory,
            demand=demand,
            maximum_inventory=maximum_inventory,
        )
        v_index_to_code[v + 1] = Int(customer_code)
    end
    return customers, v_index_to_code
end

"""
    read_distances_CSV(path::String, dims::NamedTuple, v_index_to_code::Vector{Int})

Get the distances matrix from a `CSV` file.

We check that the indices of the rows and columns indeed correspond to 
the sites indices used when reading depots and customers.
"""
function read_distances_CSV(path::String, dims::NamedTuple, v_index_to_code::Vector{Int})
    df_dist = DataFrame(CSV.File(joinpath(path, "distances.csv")))
    indices_names = df_dist.Column1
    columns_names = parse.(Int, names(select!(df_dist, Not(:Column1))))
    @assert(indices_names == columns_names == v_index_to_code)
    dist = Matrix(df_dist)
    return dist
end

"""
    read_transport_durations_CSV(path::String, dims::NamedTuple, v_index_to_code::Vector{Int})

Get the transport durations matrix from a `CSV` file.

We check that the indices of the rows and columns indeed correspond to 
the sites indices used when reading depots and customers.
"""
function read_transport_durations_CSV(
    path::String, dims::NamedTuple, v_index_to_code::Vector{Int}
)
    df_durations = DataFrame(CSV.File(joinpath(path, "transport_durations.csv")))
    indices_names = df_durations.Column1
    columns_names = parse.(Int, names(select!(df_durations, Not(:Column1))))
    @assert(indices_names == columns_names == v_index_to_code)
    durations = Matrix(df_durations)
    return durations
end

"""
    read_instance_CSV(path_to_folder::String)::Instance

Create an instance from `CSV` files.

An instance folder has:
- one master data file.
- one file on commodities.
- one file on customers indices.
- one file on depots indices.
- one file on distances.
- one file on transport durations.
- one folder per customer.
- one folder per depot.
"""
function read_instance_CSV(path_to_folder::String)::Instance
    dims = read_dimensions_CSV(path_to_folder)
    commodities, commodities_names = read_commodities_CSV(path_to_folder)
    depots, v_index_to_code = read_depots_CSV(path_to_folder, dims, commodities_names)
    customers, v_index_to_code = read_customers_CSV(
        path_to_folder, dims, commodities_names, v_index_to_code
    )
    dist = read_distances_CSV(path_to_folder, dims, v_index_to_code)
    transp_durations = read_transport_durations_CSV(path_to_folder, dims, v_index_to_code)

    return Instance(;
        T=dims.T,
        D=dims.D,
        C=dims.C,
        M=dims.M,
        vehicle_capacity=dims.vehicle_capacity,
        km_cost=dims.km_cost,
        vehicle_cost=dims.vehicle_cost,
        stop_cost=dims.stop_cost,
        nb_transport_hours_per_day=dims.nb_transport_hours_per_day,
        S_max=3,
        commodities=commodities,
        depots=depots,
        customers=customers,
        dist=dist,
        transport_durations=transp_durations,
        solution=StructuredSolution(dims.T, dims.D),
    )
end

function read_instance_ZIP()
    instances_path = joinpath(datadep"IRP-instances", "instances.zip")
    instances_zip = ZipFile.Reader(instances_path)
    try
        filenames = [f.name for f in instances_zip.files]
        return filenames
    finally
        close(instances_zip)
    end
end
