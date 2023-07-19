"""
    Site

A site is a generic place where inventory is monitored.
"""
abstract type Site end

get_M(site::Site) = length(site.initial_inventory)
get_T(site::Site) = size(site.maximum_inventory, 2)

uses_commodity(site::Site, m::Int)::Bool = site.commodity_used[m]
commodities_used(site::Site)::Vector{Bool} =
    [uses_commodity(site, m) for m in 1:get_M(site)]

"""
    positive_inventory(site::Site)

Check if the `site` inventory is nonnegative.
"""
function positive_inventory(site::Site)
    for x in site.inventory
        if x < 0
            return false
        end
    end
    return true
end
