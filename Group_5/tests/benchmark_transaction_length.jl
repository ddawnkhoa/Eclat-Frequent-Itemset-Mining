# tests/benchmark_transaction_length.jl
using Statistics
using Printf

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

const BENCHMARK_DIR = joinpath(
    PROJECT_ROOT,
    "data",
    "benchmark",
    "transaction_length",
)

const RESULTS_DIR = joinpath(
    PROJECT_ROOT,
    "results",
    "transaction_length",
)

const CSV_FILE = joinpath(
    RESULTS_DIR,
    "transaction_length_runtime.csv",
)

const LENGTHS = [5, 10, 15, 20, 25]
const REPEATS = 3
const MINSUP_PERCENT = 5

const ALGORITHM_NAME = "Julia BitVector"
const ALGORITHM_CLI = "bitvector"

const COLUMNS = [
    "Dataset",
    "AvgTransactionLength",
    "Transactions",
    "MinSupPercent",
    "MinSupCount",
    "Algorithm",
    "Repeats",
    "Run1Sec",
    "Run2Sec",
    "Run3Sec",
    "MedianSec",
    "MaxSec",
]

# Escape gia tri CSV.
function csv_escape(value)
    if value === nothing || ismissing(value)
        return ""
    end

    text = string(value)
    text = replace(text, "\"" => "\"\"")

    return "\"" * text * "\""
end

function csv_line(values)
    return join(csv_escape.(values), ",")
end

# Kiem tra schema CSV neu file da ton tai.
function validate_csv_header(path)
    if !isfile(path)
        return
    end

    lines = readlines(path)

    if isempty(lines)
        error("CSV ton tai nhung rong: $path")
    end

    existing_header = strip(first(lines))
    expected_header = csv_line(COLUMNS)

    if existing_header != expected_header
        error(
            "CSV co schema khac. Hay doi ten/xoa file truoc khi chay: $path",
        )
    end
end

# Dem so dong giao dich trong dataset.
# Moi dong duoc tinh la mot giao dich, giong PowerShell Get-Content.
function count_transactions(path)
    count = 0

    for _ in eachline(path)
        count += 1
    end

    return count
end

# Chay main.jl va do thoi gian toan bo process.
function run_and_measure(command)
    start_time = time_ns()

    process = run(
        pipeline(command, stdout = devnull, stderr = devnull);
        wait = false,
    )

    wait(process)

    elapsed_seconds = (time_ns() - start_time) / 1e9

    if !success(process)
        return false, elapsed_seconds
    end

    return true, elapsed_seconds
end

function main()
    mkpath(RESULTS_DIR)
    validate_csv_header(CSV_FILE)

    results = Vector{Vector{Any}}()

    julia_executable = joinpath(Sys.BINDIR, "julia")
    main_file = joinpath(PROJECT_ROOT, "src", "main.jl")

    for length_value in LENGTHS
        dataset_name = "Synthetic-L$(length_value)"

        input_file = joinpath(
            BENCHMARK_DIR,
            "synthetic_L$(length_value).txt",
        )

        if !isfile(input_file)
            @warn "Khong tim thay dataset. Bo qua." input_file
            continue
        end

        # Dem so giao dich thuc te.
        transaction_count = count_transactions(input_file)

        if transaction_count <= 0
            @warn "Dataset rong. Bo qua." input_file
            continue
        end

        minsup_count = ceil(
            Int,
            transaction_count * MINSUP_PERCENT / 100,
        )

        output_file = joinpath(
            BENCHMARK_DIR,
            "result_L$(length_value)_bitvector.txt",
        )

        println()
        println("==========================================")
        println(dataset_name)
        println("Transactions : $(transaction_count)")
        println("Avg length  : $(length_value)")
        println("MinSup      : $(MINSUP_PERCENT)% ($(minsup_count))")
        println("Algorithm   : $(ALGORITHM_NAME)")
        println("==========================================")

        times = Float64[]

        for run_number in 1:REPEATS
            println(
                "$(ALGORITHM_NAME) - run ",
                "$(run_number)/$(REPEATS)",
            )

            command = `$(julia_executable) --project=$(PROJECT_ROOT) $(main_file) $(input_file) $(MINSUP_PERCENT) $(output_file) $(ALGORITHM_CLI)`

            succeeded, seconds = run_and_measure(command)

            if !succeeded
                @warn "Julia failed" dataset_name run_number
                continue
            end

            rounded_seconds = round(seconds; digits = 4)
            push!(times, rounded_seconds)

            @printf("Runtime: %.4f sec\n", rounded_seconds)
        end

        if isempty(times)
            @warn "Khong co run thanh cong cho $(dataset_name)."
            continue
        end

        median_seconds = median(times)
        maximum_seconds = maximum(times)

        # Neu run that bai, cot run tuong ung se de trong.
        run_values = Any[nothing, nothing, nothing]

        for i in 1:min(length(times), REPEATS)
            run_values[i] = times[i]
        end

        row = Any[
            dataset_name,
            length_value,
            transaction_count,
            MINSUP_PERCENT,
            minsup_count,
            ALGORITHM_NAME,
            length(times),
            run_values[1],
            run_values[2],
            run_values[3],
            round(median_seconds; digits = 4),
            round(maximum_seconds; digits = 4),
        ]

        push!(results, row)

        @printf("Median runtime: %.4f sec\n", median_seconds)
        @printf("Maximum runtime: %.4f sec\n", maximum_seconds)
    end

    if isempty(results)
        @warn "Khong co ket qua nao de ghi CSV."
        return
    end

    file_exists = isfile(CSV_FILE)

    open(CSV_FILE, file_exists ? "a" : "w") do file
        if !file_exists
            println(file, csv_line(COLUMNS))
        end

        for row in results
            println(file, csv_line(row))
        end
    end

    println()
    println(
        file_exists ? "Appended CSV: " : "Created CSV: ",
        CSV_FILE,
    )

    println()
    println("Benchmark transaction length completed.")
end

main()
