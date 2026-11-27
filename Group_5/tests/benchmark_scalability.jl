
# tests/benchmark_scalability.jl
using Statistics
using Printf

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

const BENCHMARK_DIR = joinpath(PROJECT_ROOT, "data", "benchmark")
const RESULTS_DIR = joinpath(PROJECT_ROOT, "results", "scalability")
const CSV_FILE = joinpath(RESULTS_DIR, "scalability_runtime.csv")

const REPEATS = 3
const MINSUP_PERCENT = 3
const ALGORITHM_NAME = "Julia BitVector"
const ALGORITHM_CLI = "bitvector"

# So giao dich: Floor(88162 * percentage / 100)
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

# Kiem tra header neu CSV da ton tai.
function validate_csv_header(path)
    if !isfile(path)
        return
    end

    existing_header = strip(first(readlines(path)))
    expected_header = csv_line(COLUMNS)

    if existing_header != expected_header
        error(
            "CSV co schema khac. Hay doi ten/xoa file: $path"
        )
    end
end

# Dem so giao dich trong file.
# Moi dong khong rong duoc xem la mot giao dich.
function count_transactions(path)
    count = 0

    for line in eachline(path)
        if !isempty(strip(line))
            count += 1
        end
    end

    return count
end

# Chay Julia main.jl va do thoi gian toan bo process.
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

    for test_case in TEST_CASES
        percent = test_case.percent
        expected_n = test_case.transactions

        input_file = joinpath(
            BENCHMARK_DIR,
            "retail_$(percent).txt",
        )

        if !isfile(input_file)
            @warn "Khong tim thay dataset" input_file
            continue
        end

        # Xac minh so giao dich thuc te.
        actual_n = count_transactions(input_file)
        n_transactions = actual_n

        if actual_n != expected_n
            @warn "So giao dich khac expected" input_file actual_n expected_n
        end

        minsup_count = ceil(Int, n_transactions * MINSUP_PERCENT / 100)

        println()
        println(
            "Retail $(percent)% | Transactions: $(n_transactions) | ",
            "MinSup: $(MINSUP_PERCENT)% ($(minsup_count))",
        )

        times = Float64[]

        # File output itemset nam truc tiep trong data/benchmark.
        output_file = joinpath(
            BENCHMARK_DIR,
            "retail_$(percent)_julia_bitvector.txt",
        )

        for run_number in 1:REPEATS
            println(
                "$(ALGORITHM_NAME) - run ",
                "$(run_number)/$(REPEATS)",
            )

            command = `$(julia_executable) --project=$(PROJECT_ROOT) $(main_file) $(input_file) $(MINSUP_PERCENT) $(output_file) $(ALGORITHM_CLI)`

            succeeded, seconds = run_and_measure(command)

            if !succeeded
                @warn "Julia failed" percent run_number
                continue
            end

            push!(times, round(seconds; digits = 4))

            @printf("Runtime: %.4f sec\n", times[end])
        end

        if isempty(times)
            @warn "No successful runs for Retail $(percent)%"
            continue
        end

        median_seconds = median(times)
        maximum_seconds = maximum(times)

        # Tao 3 cot Run, neu run that bai thi de trong.
        run_values = Any[nothing, nothing, nothing]

        for i in 1:min(length(times), REPEATS)
            run_values[i] = times[i]
        end

        row = Any[
            "Retail",
            percent,
            n_transactions,
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
        @warn "No results to write."
        return
    end

    # Ghi CSV: append neu da co file, tao moi neu chua co.
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
        file_exists ? "Appended results: " : "Created CSV: ",
        CSV_FILE,
    )
end

main()
