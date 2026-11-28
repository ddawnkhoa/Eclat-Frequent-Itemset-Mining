
# tests/benchmark_runtime.jl
#
# Run from project root:
# julia --project=. tests/benchmark_runtime.jl

using Statistics
using Printf

# --------------------------------------------------
# 1. Configuration
# --------------------------------------------------

datasets = [
    # "chess.txt",
    # "mushroom.txt",
    # "retail.txt",
    "T10I4D100K.txt"
]

percentages = [5, 4, 3, 2, 1]
repeats = 3

PROJECT_DIR = dirname(@__DIR__)

input_dir = joinpath(PROJECT_DIR, "data", "benchmark")
output_dir = joinpath(PROJECT_DIR, "data", "benchmark")
results_dir = joinpath(PROJECT_DIR, "results", "runtime")

mkpath(results_dir)

csv_file = joinpath(results_dir, "julia_runtime.csv")

# --------------------------------------------------
# 2. CSV schema
# --------------------------------------------------

columns = [
    "Dataset",
    "Transactions",
    "MinsupPercent",
    "MinsupCount",
    "Algorithm",
    "Repeats",
    "Run1Sec",
    "Run2Sec",
    "Run3Sec",
    "MedianSec"
]

# --------------------------------------------------
# 3. Helper functions
# --------------------------------------------------

function count_transactions(filepath::String)
    transaction_count = 0

    for line in eachline(filepath)
        stripped = strip(line)

        if isempty(stripped) || occursin(r"^[@#%]", stripped)
            continue
        end

        transaction_count += 1
    end

    return transaction_count
end

function write_csv_row(file, row)
    escaped_row = [
        "\"" * replace(value, "\"" => "\"\"") * "\""
        for value in row
    ]

    println(file, join(escaped_row, ","))
end

# --------------------------------------------------
# 4. Check existing CSV
# --------------------------------------------------

if isfile(csv_file)
    println("Existing CSV found. Results will be appended.")
else
    println("CSV file does not exist. A new file will be created.")
end

# --------------------------------------------------
# 5. Benchmark
# --------------------------------------------------

results = Vector{Vector{String}}()

julia_command = Base.julia_cmd()

cd(PROJECT_DIR) do

    for dataset in datasets

        input_file = joinpath(input_dir, dataset)
        base_name = splitext(dataset)[1]

        if !isfile(input_file)
            @warn "Dataset not found: $input_file"
            continue
        end

        # Count transactions
        N = count_transactions(input_file)

        println("\nDataset: $dataset, Transactions: $N")

        for percent in percentages

            # Calculate minimum support count
            minsup = ceil(Int, N * percent / 100)

            # Output file
            output_file = joinpath(
                output_dir,
                "$(base_name)_julia_$(percent).txt"
            )

            times = Float64[]

            for run_number in 1:repeats

                println(
                    "MinSup $percent% (count=$minsup), " *
                    "run $run_number/$repeats"
                )

                # Measure the entire Julia process
                command = `$julia_command --project=. src/main.jl $input_file $percent $output_file bitvector`

                start_time = time_ns()

                try
                    run(command)

                    elapsed = (time_ns() - start_time) / 1e9

                    push!(times, elapsed)

                    @printf("Runtime: %.4f seconds\n", elapsed)

                catch err
                    @warn "Julia failed: $dataset minsup=$percent run=$run_number" exception=(err, catch_backtrace())
                end
            end

            if isempty(times)
                @warn "No successful runs for $dataset minsup=$percent"
                continue
            end

            # Calculate median runtime
            median_time = median(times)

            # Individual run times
            run_times = [
                i <= length(times) ?
                    @sprintf("%.4f", times[i]) : ""
                for i in 1:3
            ]

            # Create result row
            row = [
                base_name,
                string(N),
                string(percent),
                string(minsup),
                "Julia BitVector",
                string(length(times)),
                run_times[1],
                run_times[2],
                run_times[3],
                @sprintf("%.4f", median_time)
            ]

            push!(results, row)

            @printf(
                "Median runtime: %.4f seconds\n",
                median_time
            )
        end
    end
end

# --------------------------------------------------
# 6. Write CSV
# --------------------------------------------------

if !isempty(results)

    write_header = !isfile(csv_file) || filesize(csv_file) == 0

    open(csv_file, "a") do file

        if write_header
            write_csv_row(file, columns)
        end

        for row in results
            write_csv_row(file, row)
        end
    end

    println("\nResults appended to: $csv_file")

else
    @warn "No results to write."
end

println("\n========== BENCHMARK COMPLETED ==========")
