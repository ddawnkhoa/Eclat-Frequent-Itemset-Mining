using Statistics
using Printf

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


# Đo thời gian và bộ nhớ trung vị qua nhiều lần chạy
function measure_algorithm(f; repetitions=10)

    # Warm-up
    f()

    times = Float64[]
    memories = Int[]

    for _ in 1:repetitions
        GC.gc()

        push!(times, @elapsed f())
        push!(memories, @allocated f())
    end

    return (
        runtime = median(times),
        memory = median(memories)
    )
end


function benchmark_optimization(filepath, minsup; repetitions=10)

    transactions = load_spmf_file(filepath)

    # Xây dựng hai cấu trúc dữ liệu
    db_vector = build_vertical_db(transactions)
    db_bitvector = build_vertical_bit_db(transactions)

    # Kiểm tra tính đúng đắn trước khi đo
    result_vector = eclat(db_vector, minsup)
    result_bitvector = eclat_bitvector(db_bitvector, minsup)

    if result_to_dict(result_vector) != result_to_dict(result_bitvector)
        error("Results do not match: $(basename(filepath))")
    end

    # Đo riêng thời gian khai thác
    vector_metrics = measure_algorithm(
        () -> eclat(db_vector, minsup);
        repetitions=repetitions
    )

    bitvector_metrics = measure_algorithm(
        () -> eclat_bitvector(db_bitvector, minsup);
        repetitions=repetitions
    )

    speedup = vector_metrics.runtime / bitvector_metrics.runtime

    memory_ratio = bitvector_metrics.memory == 0 ?
        NaN : vector_metrics.memory / bitvector_metrics.memory

    println("\n========================================")
    println("Dataset: ", basename(filepath))
    println("Transactions: ", length(transactions))
    println("Minsup: ", minsup)
    println("Frequent itemsets: ", length(result_vector))
    println("Correctness: PASS")

    println("\nVector:")
    @printf("Runtime: %.6f seconds\n", vector_metrics.runtime)
    @printf("Allocated memory: %.2f KB\n",
        vector_metrics.memory / 1024)

    println("\nBitVector:")
    @printf("Runtime: %.6f seconds\n", bitvector_metrics.runtime)
    @printf("Allocated memory: %.2f KB\n",
        bitvector_metrics.memory / 1024)

    @printf("\nSpeedup: %.3fx\n", speedup)
    @printf("Memory ratio: %.3fx\n", memory_ratio)

    if speedup > 1
        println("Runtime improvement: BitVector is faster.")
    elseif speedup < 1
        println("Runtime improvement: Vector is faster.")
    else
        println("Runtime: Equal.")
    end

    println("========================================")
end


# Thực hiện benchmark
project_dir = dirname(@__DIR__)
data_dir = joinpath(project_dir, "data", "toy")

datasets = [
    ("normal.txt", 2),
    ("singleton_only.txt", 3),
    ("no_frequent.txt", 3),
    ("multi_itemset.txt", 3)
]

for (filename, minsup) in datasets
    filepath = joinpath(data_dir, filename)

    benchmark_optimization(filepath, minsup)
end
