
using Statistics
using Printf

include("../src/structures.jl")
include("../src/structures_bitvector.jl")
include("../src/algorithm/eclat.jl")
include("../src/algorithm/eclat_bitvector.jl")
include("../src/data_loader.jl")

function result_to_dict(results)
    return Dict(
        Tuple(itemset) => support
        for (itemset, support) in results
    )
end

# Đo runtime và tổng lượng bộ nhớ cấp phát
function measure_algorithm(f; repetitions=10)
    f()  # Warm-up

    times = Float64[]
    memories = Int[]

    for _ in 1:repetitions
        GC.gc()
        push!(times, @elapsed f())

        GC.gc()
        push!(memories, @allocated f())
    end

    return (
        runtime = median(times),
        memory = median(memories)
    )
end

function benchmark_optimization(filepath, minsup; repetitions=10)
    transactions = load_spmf_file(filepath)

    # Xây dựng cấu trúc dữ liệu
    db_vector = build_vertical_db(transactions)
    db_bitvector = build_vertical_bit_db(transactions)

    # Kiểm tra correctness
    result_vector = eclat(db_vector, minsup)
    result_bitvector = eclat_bitvector(db_bitvector, minsup)

    if result_to_dict(result_vector) != result_to_dict(result_bitvector)
        error("Results do not match: $(basename(filepath))")
    end

    # Đo riêng thời gian và bộ nhớ của thuật toán
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

    return (
        Dataset = basename(filepath),
        Transactions = length(transactions),
        MinSup = minsup,
        ItemsetCount = length(result_vector),
        Correctness = "PASS",
        VectorRuntimeSec = vector_metrics.runtime,
        BitVectorRuntimeSec = bitvector_metrics.runtime,
        Speedup = speedup,
        VectorAllocatedMB = vector_metrics.memory / 1024^2,
        BitVectorAllocatedMB = bitvector_metrics.memory / 1024^2,
        MemoryRatio = memory_ratio
    )
end

# Các bộ dữ liệu toy
project_dir = dirname(@__DIR__)
data_dir = joinpath(project_dir, "data", "toy")

datasets = [
    ("normal.txt", 2),
    ("empty.txt", 1),
    ("singleton_only.txt", 3),
    ("no_frequent.txt", 3),
    ("multi_itemset.txt", 2)
]

results = []

for (filename, minsup) in datasets
    filepath = joinpath(data_dir, filename)

    metrics = benchmark_optimization(
        filepath, minsup;
        repetitions=10
    )

    push!(results, metrics)

    println("\nDataset: ", metrics.Dataset)
    println("Correctness: ", metrics.Correctness)
    println("Frequent itemsets: ", metrics.ItemsetCount)

    @printf("Vector runtime: %.6f s\n", metrics.VectorRuntimeSec)
    @printf("BitVector runtime: %.6f s\n", metrics.BitVectorRuntimeSec)
    @printf("Speedup: %.3fx\n", metrics.Speedup)

    @printf("Vector allocated: %.4f MB\n", metrics.VectorAllocatedMB)
    @printf("BitVector allocated: %.4f MB\n", metrics.BitVectorAllocatedMB)
    @printf("Memory ratio: %.3fx\n", metrics.MemoryRatio)
end

# Xuất CSV
output_dir = joinpath(project_dir, "results", "optimization")
mkpath(output_dir)

output_file = joinpath(output_dir, "vector_bitvector_optimization.csv")

columns = [
    "Dataset", "Transactions", "MinSup", "ItemsetCount",
    "Correctness", "VectorRuntimeSec", "BitVectorRuntimeSec",
    "Speedup", "VectorAllocatedMB", "BitVectorAllocatedMB",
    "MemoryRatio"
]

open(output_file, "w") do io
    println(io, join(columns, ","))

    for r in results
        println(io, join([
            r.Dataset,
            r.Transactions,
            r.MinSup,
            r.ItemsetCount,
            r.Correctness,
            r.VectorRuntimeSec,
            r.BitVectorRuntimeSec,
            r.Speedup,
            r.VectorAllocatedMB,
            r.BitVectorAllocatedMB,
            r.MemoryRatio
        ], ","))
    end
end

println("\nSaved benchmark results: ", output_file)
