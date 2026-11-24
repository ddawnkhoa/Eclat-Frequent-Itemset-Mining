using Test

include("../src/structures.jl")
include("../src/structures_bitvector.jl")

include("../src/algorithm/eclat.jl")
include("../src/algorithm/eclat_bitvector.jl")

include("../src/data_loader.jl")

# Chuyển kết quả về Dict để so sánh
function result_to_dict(results)
    return Dict(
        Tuple(itemset) => support
        for (itemset, support) in results
    )
end

@testset "Eclat Vector vs BitVector" begin

    project_dir = dirname(@__DIR__)
    data_dir = joinpath(project_dir, "data", "toy")

    datasets = [
        ("normal.txt", 2),
        ("empty.txt", 1),
        ("singleton_only.txt", 3),
        ("no_frequent.txt", 3),
        ("multi_itemset.txt", 3)
    ]

    for (filename, minsup) in datasets

        println("\nTesting: ", filename)

        filepath = joinpath(data_dir, filename)
        transactions = load_spmf_file(filepath)

        # Phiên bản Vector
        db_vector = build_vertical_db(transactions)
        result_vector = eclat(db_vector, minsup)

        # Phiên bản BitVector
        db_bitvector = build_vertical_bit_db(transactions)
        result_bitvector = eclat_bitvector(db_bitvector, minsup)

        # So sánh kết quả
        @test result_to_dict(result_vector) ==
              result_to_dict(result_bitvector)

        println("Vector itemsets: ", length(result_vector))
        println("BitVector itemsets: ", length(result_bitvector))
        println("Result: PASS")
    end
end
