using Test
include("../src/algorithm/rules.jl")
using .AssociationRules

@testset "Association Rules Unit Tests" begin
    total_transactions::Int = 4
    frequent_itemsets = Dict{Vector{Int}, Int}(
        [1] => 3,
        [2] => 3,
        [3] => 1,
        [4] => 1,
        [1, 2] => 2
    )

    rules = generate_rules(frequent_itemsets, total_transactions, 0.6)
    @test length(rules) == 2

    first_rule = rules[1]
    @test isapprox(first_rule.support, 2 / 4; atol = 1e-6)
    @test isapprox(first_rule.confidence, 2 / 3; atol = 1e-6)
    @test isapprox(first_rule.lift, (2 / 3) / (3 / 4); atol = 1e-6)
end