
# tests/benchmark_memory.jl
# Run from project root:
# julia --project=. tests/benchmark_memory.jl
#
# Measure Peak Working Set (RAM peak) of Julia subprocesses
# for Vector and BitVector algorithms on Windows.

using Statistics
using Printf

if !Sys.iswindows()
    error("This script measures Peak Working Set using Windows API and must run on Windows.")
end

# --------------------------------------------------
# 1. Project paths and benchmark settings
# --------------------------------------------------

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

const INPUT_DIR = joinpath(PROJECT_ROOT, "data", "benchmark")
const OUTPUT_DIR = INPUT_DIR
const RESULTS_DIR = joinpath(PROJECT_ROOT, "results", "memory")
const CSV_FILE = joinpath(RESULTS_DIR, "memory_runtime.csv")

const REPEATS = 3
const POLL_INTERVAL = 0.05  # 50 ms

# MinSup trung binh trong cac day benchmark
const TEST_CASES = [
    (dataset = "chess",      transactions = 3196,   minsup_percent = 60),
    (dataset = "mushroom",   transactions = 8124,   minsup_percent = 30),
    (dataset = "retail",     transactions = 88162,  minsup_percent = 3),
    (dataset = "T10I4D100K", transactions = 100000, minsup_percent = 3),
]

# CLI algorithm key must match src/main.jl
const ALGORITHMS = [
    (name = "Julia Vector",    cli = "vector"),
    (name = "Julia BitVector", cli = "bitvector"),
]

const COLUMNS = [
    "Dataset",
    "Transactions",
    "MinsupPercent",
    "MinsupCount",
    "Algorithm",
    "Repeats",
    "Run1PeakRAM_MB",
    "Run2PeakRAM_MB",
    "Run3PeakRAM_MB",
    "MedianPeakRAM_MB",
    "MaxPeakRAM_MB",
]

mkpath(RESULTS_DIR)


# --------------------------------------------------
# 2. Windows API: get process Peak Working Set
# --------------------------------------------------

# Windows PROCESS_MEMORY_COUNTERS structure.
# SIZE_T is UInt on the current Windows architecture.
struct PROCESS_MEMORY_COUNTERS
    cb::UInt32
    PageFaultCount::UInt32
    PeakWorkingSetSize::UInt
    WorkingSetSize::UInt
    QuotaPeakPagedPoolUsage::UInt
    QuotaPagedPoolUsage::UInt
    QuotaPeakNonPagedPoolUsage::UInt
    QuotaNonPagedPoolUsage::UInt
    PagefileUsage::UInt
    PeakPagefileUsage::UInt
end

function get_peak_working_set_bytes(pid::Integer)
    PROCESS_QUERY_INFORMATION = UInt32(0x0400)

    handle = ccall(
        (:OpenProcess, "kernel32"),
        Ptr{Cvoid},
        (UInt32, Int32, UInt32),
        PROCESS_QUERY_INFORMATION,
        0,
        UInt32(pid),
    )

    if handle == C_NULL
        return 0.0
    end

    try
        counters = Ref(
            PROCESS_MEMORY_COUNTERS(
                UInt32(sizeof(PROCESS_MEMORY_COUNTERS)),
                UInt32(0),
                UInt(0), UInt(0),
                UInt(0), UInt(0),
                UInt(0), UInt(0),
                UInt(0), UInt(0),
            )
        )

        success = ccall(
            (:GetProcessMemoryInfo, "psapi"),
            Int32,
            (Ptr{Cvoid}, Ref{PROCESS_MEMORY_COUNTERS}, UInt32),
            handle,
            counters,
            UInt32(sizeof(PROCESS_MEMORY_COUNTERS)),
        )

        if success == 0
            return 0.0
        end

        return Float64(counters[].PeakWorkingSetSize)
    finally
        ccall(
            (:CloseHandle, "kernel32"),
            Int32,
            (Ptr{Cvoid},),
            handle,
        )
    end
end


# --------------------------------------------------
# 3. Run Julia subprocess and monitor peak RAM
# --------------------------------------------------

function run_and_measure_peak(command::Cmd)
    process = run(command; wait = false)

    peak_bytes = 0.0

    while process_running(process)
        try
            current_peak = get_peak_working_set_bytes(process.pid)

            if current_peak > peak_bytes
                peak_bytes = current_peak
            end
        catch
            # Process may exit while querying its memory.
        end

        sleep(POLL_INTERVAL)
    end

    wait(process)

    if process.exitcode != 0
        return (success = false, peak_mb = 0.0, exitcode = process.exitcode)
    end

    if peak_bytes <= 0
        return (success = false, peak_mb = 0.0, exitcode = process.exitcode)
    end

    peak_mb = round(peak_bytes / 1024^2; digits = 2)

    return (success = true, peak_mb = peak_mb, exitcode = process.exitcode)
end


# --------------------------------------------------
# 4. CSV helpers
# --------------------------------------------------

# Quote every field to keep CSV format consistent with
# PowerShell Export-Csv output.
function csv_escape(value)
    if value === missing || value === nothing
        text = ""
    else
        text = string(value)
    end

    text = replace(text, "\"" => "\"\"")
    return "\"" * text * "\""
end

function csv_line(values)
    return join(csv_escape.(values), ",")
end

function validate_csv_header(path::String)
    expected_header = csv_line(COLUMNS)

    if isfile(path)
        existing_header = strip(first(readlines(path)))

        if existing_header != expected_header
            error(
                "CSV has a different schema. Rename or remove this file: $path"
            )
        end
    end
end

function append_csv_rows(path::String, rows)
    file_exists = isfile(path)

    open(path, "a") do file
        if !file_exists
            println(file, csv_line(COLUMNS))
        end

        for row in rows
            values = [getproperty(row, Symbol(column)) for column in COLUMNS]
            println(file, csv_line(values))
        end
    end
end


# --------------------------------------------------
# 5. Benchmark
# --------------------------------------------------

validate_csv_header(CSV_FILE)

results = NamedTuple[]

for case in TEST_CASES
    dataset = case.dataset
    N = case.transactions
    percent = case.minsup_percent

    input_file = joinpath(INPUT_DIR, dataset * ".txt")
    minsup_count = ceil(Int, N * percent / 100)

    if !isfile(input_file)
        @warn "Dataset not found: $input_file"
        continue
    end

    println()
    println("Dataset: $dataset | MinSup: $percent% | Count: $minsup_count")

    for algorithm in ALGORITHMS
        algorithm_name = algorithm.name
        algorithm_cli = algorithm.cli

        output_file = joinpath(
            OUTPUT_DIR,
            "$(dataset)_julia_$(percent)_$(algorithm_cli).txt",
        )

        peak_values_mb = Float64[]

        for run_number in 1:REPEATS
            println("$algorithm_name - run $run_number/$REPEATS")

            command = `julia --project=$(PROJECT_ROOT) $(joinpath(PROJECT_ROOT, "src", "main.jl")) $input_file $percent $output_file $algorithm_cli`

            measurement = run_and_measure_peak(command)

            if !measurement.success
                @warn "Julia failed or peak RAM unavailable" dataset algorithm_cli run_number exitcode=measurement.exitcode
                continue
            end

            push!(peak_values_mb, measurement.peak_mb)

            println("Peak RAM: $(measurement.peak_mb) MB")
        end

        if isempty(peak_values_mb)
            @warn "No successful runs: $dataset / $algorithm_cli"
            continue
        end

        median_peak = round(median(peak_values_mb); digits = 2)
        max_peak = round(maximum(peak_values_mb); digits = 2)

        # Preserve the order of successful runs.
        run1 = length(peak_values_mb) >= 1 ? peak_values_mb[1] : missing
        run2 = length(peak_values_mb) >= 2 ? peak_values_mb[2] : missing
        run3 = length(peak_values_mb) >= 3 ? peak_values_mb[3] : missing

        row = (
            Dataset = dataset,
            Transactions = N,
            MinsupPercent = percent,
            MinsupCount = minsup_count,
            Algorithm = algorithm_name,
            Repeats = length(peak_values_mb),
            Run1PeakRAM_MB = run1,
            Run2PeakRAM_MB = run2,
            Run3PeakRAM_MB = run3,
            MedianPeakRAM_MB = median_peak,
            MaxPeakRAM_MB = max_peak,
        )

        push!(results, row)

        println("Median peak RAM: $median_peak MB")
        println("Maximum peak RAM: $max_peak MB")
    end
end


# --------------------------------------------------
# 6. Append results to CSV
# --------------------------------------------------

if !isempty(results)
    append_csv_rows(CSV_FILE, results)

    println()
    println("Appended results: $CSV_FILE")
else
    @warn "No results to write."
end
