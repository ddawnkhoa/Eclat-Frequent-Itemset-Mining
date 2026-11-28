
# tests/benchmark_memory.jl
#
# Run from project root:
# julia --project=. tests/benchmark_memory.jl
#
# Measure Peak Working Set (RAM peak) of Julia subprocesses
# for Vector and BitVector algorithms on Windows.
#
# This script follows the measurement procedure of
# benchmark_memory.ps1.

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
const POLL_INTERVAL = 0.05

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
# 2. Windows API: Peak Working Set
# --------------------------------------------------

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

const PROCESS_QUERY_INFORMATION = UInt32(0x0400)
const PROCESS_VM_READ = UInt32(0x0010)

function open_process_handle(pid::Integer)

    handle = ccall(
        (:OpenProcess, "kernel32"),
        Ptr{Cvoid},
        (UInt32, Int32, UInt32),
        PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
        0,
        UInt32(pid),
    )

    if handle == C_NULL
        error_code = ccall(
            (:GetLastError, "kernel32"),
            UInt32,
            (),
        )

        error(
            "OpenProcess failed. PID=$pid, Windows error=$error_code"
        )
    end

    return handle
end

function close_process_handle(handle::Ptr{Cvoid})

    if handle != C_NULL
        ccall(
            (:CloseHandle, "kernel32"),
            Int32,
            (Ptr{Cvoid},),
            handle,
        )
    end

    return nothing
end

function get_peak_working_set_bytes(handle::Ptr{Cvoid})

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
        error_code = ccall(
            (:GetLastError, "kernel32"),
            UInt32,
            (),
        )

        error(
            "GetProcessMemoryInfo failed. Windows error=$error_code"
        )
    end

    return Float64(counters[].PeakWorkingSetSize)
end

# --------------------------------------------------
# 3. Run Julia subprocess and measure peak RAM
# --------------------------------------------------

function run_and_measure_peak(command::Cmd)

    process = run(command; wait = false)

    peak_bytes = 0.0
    handle = C_NULL

    # Get PID using Julia's process API.
    pid = getpid(process)

    try
        # Open process handle immediately after starting.
        # Keep the handle until the subprocess has exited.
        handle = open_process_handle(pid)

        # Monitor memory while the subprocess is running.
        while process_running(process)

            try
                current_peak = get_peak_working_set_bytes(handle)

                if current_peak > peak_bytes
                    peak_bytes = current_peak
                end

            catch err
                @warn "Cannot read process memory while running" pid=pid exception=err
            end

            sleep(POLL_INTERVAL)
        end

        # Wait for the subprocess to finish.
        wait(process)

        # Read Peak Working Set one final time after exit,
        # matching PowerShell's final Refresh() call.
        try
            final_peak = get_peak_working_set_bytes(handle)

            if final_peak > peak_bytes
                peak_bytes = final_peak
            end

        catch err
            @warn "Cannot read final process memory" pid=pid exception=err
        end

    catch err
        @warn "Memory measurement failed" pid=pid exception=err

        if process_running(process)
            try
                wait(process)
            catch
            end
        end

    finally
        close_process_handle(handle)
    end

    if process.exitcode != 0
        return (
            success = false,
            peak_mb = 0.0,
            exitcode = process.exitcode,
        )
    end

    if peak_bytes <= 0
        return (
            success = false,
            peak_mb = 0.0,
            exitcode = process.exitcode,
        )
    end

    peak_mb = round(peak_bytes / 1024^2; digits = 2)

    return (
        success = true,
        peak_mb = peak_mb,
        exitcode = process.exitcode,
    )
end

# --------------------------------------------------
# 4. CSV helpers
# --------------------------------------------------

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

function parse_csv_header(line::String)

    normalized = replace(line, "\ufeff" => "")

    fields = split(normalized, ",")

    return [
        strip(replace(strip(field), "\"" => ""))
        for field in fields
    ]
end

function validate_csv_header(path::String)

    if !isfile(path) || filesize(path) == 0
        println("CSV file does not exist or is empty. A new CSV will be created.")
        return
    end

    lines = readlines(path)

    if isempty(lines)
        return
    end

    existing_columns = parse_csv_header(lines[1])

    if existing_columns != COLUMNS

        println("\nExpected columns:")
        println(COLUMNS)

        println("\nExisting columns:")
        println(existing_columns)

        error("CSV has a different schema: $path")
    end

    println("Existing CSV schema is valid.")
end

function append_csv_rows(path::String, rows)

    needs_header = !isfile(path) || filesize(path) == 0

    open(path, "a") do file

        if needs_header
            println(file, csv_line(COLUMNS))
        end

        for row in rows

            values = [
                getproperty(row, Symbol(column))
                for column in COLUMNS
            ]

            println(file, csv_line(values))
        end
    end
end

# --------------------------------------------------
# 5. Benchmark
# --------------------------------------------------

validate_csv_header(CSV_FILE)

results = NamedTuple[]

julia_command = Base.julia_cmd()

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

            main_file = joinpath(PROJECT_ROOT, "src", "main.jl")

            command = `$julia_command --project=$(PROJECT_ROOT) $main_file $input_file $percent $output_file $algorithm_cli`

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

        # Calculate median and maximum
        median_peak = round(median(peak_values_mb); digits = 2)
        max_peak = round(maximum(peak_values_mb); digits = 2)

        # Preserve the order of successful runs
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

println("\n========== MEMORY BENCHMARK COMPLETED ==========")
