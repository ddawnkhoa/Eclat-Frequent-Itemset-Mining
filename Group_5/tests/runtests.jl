
using Test

const TEST_DIR = @__DIR__

println("\n========== ECLAT UNIT TESTS ==========\n")

test_files = [
    "test_correctness.jl",
    "test_bitvector.jl",
    "test_optimization.jl",
    "test_association_rules.jl",
    "test_io.jl",
    "test_spmf.jl",
]

@testset "Eclat Frequent Itemset Mining" begin
    for file in test_files
        path = joinpath(TEST_DIR, file)

        @testset "$file" begin
            if isfile(path)
                println("\nRunning $file ...")
                include(path)
            else
                @error "Test file not found: $path"
                @test false
            end
        end
    end
end

println("\n========== UNIT TESTS COMPLETED ==========\n")
