"""
    Commodity

A commodity (or product) is released by depots, demanded by customers and transported by routes. 

We consider the multi-commodity IRP in this package.

# Fields
- `m::Int`: index of the commodity.
- `l::Int`: length of a commodity.
"""
struct Commodity
    m::Int
    l::Int

    Commodity(; m, l) = new(m, l)
end

"""
    Base.show(io::IO, commodity::Commodity)

Display `commodity` in the terminal.
"""
function Base.show(io::IO, commodity::Commodity)
    str = "Commodity $(commodity.m) with length $(commodity.l)"
    return print(io, str)
end

"""
    Base.copy(commodity::Commodity)

Copy `commodity`.
"""
function Base.copy(commodity::Commodity)
    return Commodity(; m=commodity.m, l=commodity.l)
end
