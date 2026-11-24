
using Test

include("../src/structures.jl")
include("../src/algorithm/eclat.jl")

@testset "Eclat correctness" begin

    transactions = [
        [1, 2, 3],
        [1, 2],
        [1, 3],
        [2, 3],
        [1, 2, 3]
    ]

    db = build_vertical_db(transactions)

    @test db.ntransactions == 5
    @test db.tidsets[1] == [1, 2, 3, 5]
    @test db.tidsets[2] == [1, 2, 4, 5]
    @test db.tidsets[3] == [1, 3, 4, 5]

    result = eclat(db, 2)

    actual = Dict(
        Tuple(itemset) => support
        for (itemset, support) in result
    )

    expected = Dict{Tuple, Int}(
        (1,) => 4,
        (2,) => 4,
        (3,) => 4,
        (1, 2) => 3,
        (1, 3) => 3,
        (2, 3) => 3,
        (1, 2, 3) => 2
    )

    @test actual == expected
    @test length(result) == 7

    @test_throws ArgumentError eclat(db, 0)
end
