
using Test

include("../src/structures.jl")
include("../src/data_loader.jl")
include("../src/output.jl")
include("../src/algorithm/eclat.jl")

@testset "SPMF I/O tests" begin
    # Xác định đường dẫn dựa trên thư mục gốc dự án
    project_dir = dirname(@__DIR__)

    input_path = joinpath(project_dir, "data", "toy", "normal.txt")
    output_path = joinpath(project_dir, "data", "toy", "test_output.txt")

    transactions = load_spmf_file(input_path)

    @test length(transactions) == 5
    @test transactions[1] == [1, 2, 3]
    @test transactions[2] == [1, 2]

    db = build_vertical_db(transactions)
    results = eclat(db, 2)

    write_spmf_output(output_path, results)

    @test isfile(output_path)

    output_lines = readlines(output_path)

    @test length(output_lines) == 7
    @test "1 #SUP: 4" in output_lines
    @test "1 2 #SUP: 3" in output_lines
    @test "1 2 3 #SUP: 2" in output_lines

    rm(output_path)
end
