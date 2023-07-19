using Aqua
using Documenter
using InventoryRoutingLNS
using JuliaFormatter
using Test

DocMeta.setdocmeta!(
    InventoryRoutingLNS, :DocTestSetup, :(using InventoryRoutingLNS); recursive=true
)

@testset verbose = true "InventoryRoutingLNS.jl" begin
    @testset "Code quality" begin
        Aqua.test_all(InventoryRoutingLNS; ambiguities=false)
    end
    @testset "Code formatting" begin
        @test format(InventoryRoutingLNS; verbose=false, overwrite=false)
    end
    @testset "Doctests" begin
        doctest(InventoryRoutingLNS)
    end
end
