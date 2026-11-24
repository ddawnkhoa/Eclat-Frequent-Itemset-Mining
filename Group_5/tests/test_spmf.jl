using Test

include("../src/structures.jl")
include("../src/algorithm/eclat.jl")
include("../src/data_loader.jl")
include("../src/output.jl")

# Xác định đường dẫn dự án
PROJECT_DIR = dirname(@__DIR__)
DATA_DIR = joinpath(PROJECT_DIR, "data", "toy")
OUTPUT_DIR = joinpath(DATA_DIR, "outputs")

# Tạo thư mục output nếu chưa tồn tại
mkpath(OUTPUT_DIR)

# Danh sách 5 dataset và minsup tương ứng
datasets = [
    ("normal.txt", 2),
    ("empty.txt", 1),
    ("singleton_only.txt", 3),
    ("no_frequent.txt", 3),
    ("multi_itemset.txt", 2)
]

@testset "SPMF Validation - Toy Datasets" begin

    for (filename, minsup) in datasets

        println("\n================================")
        println("Dataset: ", filename)
        println("Minimum support: ", minsup)
        println("================================")

        # Đọc dữ liệu
        input_path = joinpath(DATA_DIR, filename)
        transactions = load_spmf_file(input_path)

        # Xây dựng Vertical Database
        db = build_vertical_db(transactions)

        # Chạy Eclat
        results = eclat(db, minsup)

        # Xuất kết quả Julia
        output_name = replace(filename, ".txt" => "_julia.txt")
        output_path = joinpath(OUTPUT_DIR, output_name)

        write_spmf_output(output_path, results)

        # Kiểm tra kết quả cơ bản
        @test isfile(output_path)
        @test all(support >= minsup for (_, support) in results)

        # Kiểm tra không có itemset trùng lặp
        itemsets = [Tuple(itemset) for (itemset, _) in results]
        @test length(itemsets) == length(unique(itemsets))

        println("Transactions: ", db.ntransactions)
        println("Frequent itemsets: ", length(results))
        println("Output: ", output_path)
        println("Status: PASS")
    end
end
