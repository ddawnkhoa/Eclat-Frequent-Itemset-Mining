
# tests/benchmark_scalability.jl
#
# Run from project root:
# julia --project=. tests/benchmark_scalability.jl
#
# Benchmark scalability of Retail dataset using Julia BitVector.
# Dataset subsets and output .txt files are stored directly
# in data/benchmark.
#
# Measure runtime 3 times for each dataset size.

using Statistics
using Printf

# --------------------------------------------------
# 1. Project paths and benchmark settings
# --------------------------------------------------

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

const BENCHMARK_DIR = joinpath(PROJECT_ROOT, "data", "benchmark")
const RESULTS_DIR = joinpath(PROJECT_ROOT, "results", "scalability")
const CSV_FILE = joinpath(RESULTS_DIR, "scalability_runtime.csv")

const REPEATS = 3
const MINSUP_PERCENT = 3

const ALGORITHM_NAME = "Julia BitVector"
const ALGORITHM_CLI = "bitvector"

# Expected transaction counts:
# Floor(88162 * percentage / 100)

const TEST_CASES = [
    (percent = 10,  transactions = 8816),
    (percent = 25,  transactions = 22040),
    (percent = 50,  transactions = 44081),
    (percent = 75,  transactions = 66121),
    (percent = 100, transactions = 88162),
]

const COLUMNS = [
    "Dataset",
    "DatasetPercent",
    "Transactions",
    "MinsupPercent",
    "MinsupCount",
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

# Check existing CSV schema.
function validate_csv_header(path::String)

    if !isfile(path) || filesize(path) == 0
        return
    end

    lines = readlines(path)

    if isempty(lines)
        return
    end

    existing_header = parse_csv_header(lines[1])

    if existing_header != COLUMNS
        println("Expected columns:")
        println(COLUMNS)

        println("\nExisting columns:")
        println(existing_header)

        error("CSV has a different schema: $path")
    end

    println("Existing CSV schema is valid.")
end

# --------------------------------------------------
# 3. Dataset helpers
# --------------------------------------------------

# Count all lines in the dataset.
# This follows PowerShell Measure-Object -Line.
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

# Run the Julia subprocess and measure total elapsed time.
# stdout and stderr are discarded, matching *> $null
# in the PowerShell script.

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
# 5. Median calculation
# --------------------------------------------------

function calculate_median(values::Vector{Float64})

    sorted_values = sort(values)
    count = length(sorted_values)

    if isodd(count)
        return sorted_values[(count + 1) ÷ 2]
    else
        left = sorted_values[count ÷ 2]
        right = sorted_values[count ÷ 2 + 1]

        return (left + right) / 2
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

    for test_case in TEST_CASES

        percent = test_case.percent
        expected_n = test_case.transactions

        # Input subset:
        # data/benchmark/retail_10.txt
        # data/benchmark/retail_25.txt
        # ...

        input_file = joinpath(
            BENCHMARK_DIR,
            "retail_$(percent).txt",
        )

        if !isfile(input_file)
            @warn "Dataset not found: $input_file"
            continue
        end

        # Verify actual transaction count.
        n_transactions = count_transactions(input_file)

        if n_transactions != expected_n

            @warn "Transaction count differs from expected value. Using actual count." input_file actual=n_transactions expected=expected_n
        end

        # Calculate minimum support count.
        minsup_count = ceil(
            Int,
            n_transactions * MINSUP_PERCENT / 100,
        )

        println()
        println(
            "Retail $(percent)% | Transactions: $(n_transactions) | ",
            "MinSup: $(MINSUP_PERCENT)% ($(minsup_count))",
        )

        times = Float64[]

        # Output itemset file:
        # data/benchmark/retail_<percent>_julia_bitvector.txt

        output_file = joinpath(
            BENCHMARK_DIR,
            "retail_$(percent)_julia_bitvector.txt",
        )

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

                @warn "Julia failed: Retail $(percent)% / run $(run_number)" exitcode=measurement.exitcode

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
        # Calculate statistics
        # --------------------------------------------------

        if isempty(times)

            @warn "No successful runs for Retail $(percent)%."

            continue
        end

        median_seconds = calculate_median(times)
        maximum_seconds = maximum(times)

        # Store up to three successful run results.
        # Failed runs remain empty.

        run1 = length(times) >= 1 ? times[1] : nothing
        run2 = length(times) >= 2 ? times[2] : nothing
        run3 = length(times) >= 3 ? times[3] : nothing

        row = Any[
            "Retail",
            percent,
            n_transactions,
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

        @warn "No results to write."

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
        println("Appended results: $CSV_FILE")
    else
        println("Created CSV: $CSV_FILE")
    end

    println("\n========== SCALABILITY BENCHMARK COMPLETED ==========")
end

main()
