# tests/benchmark_transaction_length.jl
using Statistics
using Printf

# --------------------------------------------------
# 1. Project paths and benchmark settings
# --------------------------------------------------

# Resolve project root from this script's location.
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

# --------------------------------------------------
# 2. CSV helpers
# --------------------------------------------------

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

function parse_csv_header(line::String)

    normalized = replace(line, "\ufeff" => "")
    fields = split(normalized, ",")

    return [
        strip(replace(strip(field), "\"" => ""))
        for field in fields
    ]
end

# Validate existing CSV schema.
function validate_csv_header(path::String)

    if !isfile(path)
        return
    end

    if filesize(path) == 0
        error("CSV exists but is empty: $path")
    end

    lines = readlines(path)

    if isempty(lines)
        error("CSV exists but has no header: $path")
    end

    existing_header = parse_csv_header(lines[1])

    if existing_header != COLUMNS

        println("Expected columns:")
        println(COLUMNS)

        println("\nExisting columns:")
        println(existing_header)

        error(
            "CSV has a different schema. Rename or remove it before running: $path",
        )
    end

    println("Existing CSV schema is valid.")
end

# --------------------------------------------------
# 3. Dataset helpers
# --------------------------------------------------

# Count all lines in the dataset.
# Equivalent to PowerShell:
# (Get-Content -Path $inputFile | Measure-Object -Line).Lines

function count_transactions(path::String)

    count = 0

    open(path, "r") do file
        for _ in eachline(file)
            count += 1
        end
    end

    return count
end

# --------------------------------------------------
# 4. Runtime measurement
# --------------------------------------------------

# Run Julia main.jl and measure the entire subprocess runtime.
#
# Equivalent to PowerShell Stopwatch:
# StartNew() -> execute Julia -> Stop()

function run_and_measure(command::Cmd)

    start_time = time_ns()

    process = run(
        pipeline(
            command,
            stdout = devnull,
            stderr = devnull,
        );
        wait = false,
    )

    wait(process)

    elapsed_seconds = (time_ns() - start_time) / 1e9

    if !success(process)

        return (
            success = false,
            seconds = elapsed_seconds,
            exitcode = process.exitcode,
        )
    end

    return (
        success = true,
        seconds = elapsed_seconds,
        exitcode = process.exitcode,
    )
end

# --------------------------------------------------
# 5. Statistics
# --------------------------------------------------

# Calculate median using the same logic as PowerShell.
function calculate_median(values::Vector{Float64})

    sorted_values = sort(values)
    count = length(sorted_values)

    if isodd(count)

        return sorted_values[(count + 1) ÷ 2]

    else

        left = sorted_values[count ÷ 2]
        right = sorted_values[count ÷ 2 + 1]

        return (left + right) / 2.0
    end
end

# --------------------------------------------------
# 6. Main benchmark
# --------------------------------------------------

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

            @warn "Dataset not found. Skipping." input_file

            continue
        end

        # Count actual transactions.
        transaction_count = count_transactions(input_file)

        if transaction_count <= 0

            @warn "Empty dataset. Skipping." input_file

            continue
        end

        # Calculate minimum support count.
        minsup_count = ceil(
            Int,
            transaction_count * MINSUP_PERCENT / 100.0,
        )

        # Output itemset file.
        output_file = joinpath(
            BENCHMARK_DIR,
            "result_L$(length_value)_bitvector.txt",
        )

        println()
        println("==========================================")
        println(dataset_name)
        println("Transactions : $(transaction_count)")
        println("Avg length   : $(length_value)")
        println("MinSup       : $(MINSUP_PERCENT)% ($(minsup_count))")
        println("Algorithm    : $(ALGORITHM_NAME)")
        println("==========================================")

        times = Float64[]

        # --------------------------------------------------
        # Run benchmark
        # --------------------------------------------------

        for run_number in 1:REPEATS

            println(
                "$(ALGORITHM_NAME) - run ",
                "$(run_number)/$(REPEATS)",
            )

            command = `$julia_executable --project=$(PROJECT_ROOT) $main_file $input_file $MINSUP_PERCENT $output_file $ALGORITHM_CLI`

            measurement = run_and_measure(command)

            if !measurement.success

                @warn "Julia failed: $(dataset_name) / run $(run_number)" exitcode=measurement.exitcode

                continue
            end

            seconds = round(
                measurement.seconds;
                digits = 4,
            )

            push!(times, seconds)

            @printf("Runtime: %.4f sec\n", seconds)
        end

        # --------------------------------------------------
        # Calculate results
        # --------------------------------------------------

        if isempty(times)

            @warn "No successful runs for $(dataset_name)."

            continue
        end

        median_seconds = calculate_median(times)
        maximum_seconds = maximum(times)

        # Store successful run times in order.
        # Failed runs are omitted, matching the PowerShell
        # behavior of appending only successful measurements.

        run1 = length(times) >= 1 ? times[1] : nothing
        run2 = length(times) >= 2 ? times[2] : nothing
        run3 = length(times) >= 3 ? times[3] : nothing

        row = Any[
            dataset_name,
            length_value,
            transaction_count,
            MINSUP_PERCENT,
            minsup_count,
            ALGORITHM_NAME,
            length(times),
            run1,
            run2,
            run3,
            round(median_seconds; digits = 4),
            round(maximum_seconds; digits = 4),
        ]

        push!(results, row)

        @printf(
            "Median runtime: %.4f sec\n",
            median_seconds,
        )

        @printf(
            "Maximum runtime: %.4f sec\n",
            maximum_seconds,
        )
    end

    # --------------------------------------------------
    # 7. Write CSV
    # --------------------------------------------------

    if isempty(results)

        @warn "No results to write to CSV."

        return
    end

    file_exists = isfile(CSV_FILE) && filesize(CSV_FILE) > 0

    open(CSV_FILE, "a") do file

        if !file_exists
            println(file, csv_line(COLUMNS))
        end

        for row in results
            println(file, csv_line(row))
        end
    end

    println()

    if file_exists
        println("Appended CSV: $CSV_FILE")
    else
        println("Created CSV: $CSV_FILE")
    end

    println()
    println("Benchmark transaction length completed.")
end

main()
