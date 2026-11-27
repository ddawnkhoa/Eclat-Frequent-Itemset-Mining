# tests/create_transaction_length_datasets.ps1
# Generate synthetic datasets for benchmark transaction length.
$ErrorActionPreference = "Stop"
using Random

# tests/ -> project root
const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))

const OUTPUT_DIR = joinpath(
    PROJECT_ROOT,
    "data",
    "benchmark",
    "transaction_length",
)

const TRANSACTION_COUNT = 10000
const ITEM_UNIVERSE = 100
const LENGTHS = [5, 10, 15, 20, 25]
const SEED = 12345

function create_dataset(length::Int)
    if length < 1 || length > ITEM_UNIVERSE
        error("Transaction length khong hop le: $length")
    end

    output_file = joinpath(
        OUTPUT_DIR,
        "synthetic_L$(length).txt",
    )

    # Khoi tao RNG rieng cho moi dataset,
    rng = MersenneTwister(SEED)

    open(output_file, "w") do writer
        for _ in 1:TRANSACTION_COUNT
            # Lay L item khong trung nhau tu 1..100.
            # randperm tao hoan vi ngau nhien.
            items = randperm(rng, ITEM_UNIVERSE)[1:length]

            # Sap xep item tang dan.
            sort!(items)

            # Ghi item cach nhau bang space.
            println(writer, join(items, " "))
        end
    end

    println("Saved: ", output_file)
end

function main()
    mkpath(OUTPUT_DIR)

    println("Project root: ", PROJECT_ROOT)
    println("Output directory: ", OUTPUT_DIR)

    for length in LENGTHS
        println()
        println("Creating dataset: L=", length)

        create_dataset(length)
    end

    println()
    println("All synthetic datasets created.")
end

main()

$projectRoot = Split-Path -Parent $PSScriptRoot

$outputDir = Join-Path $projectRoot "data\benchmark\transaction_length"
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$transactionCount = 10000
$itemUniverse = 100
$lengths = @(5, 10, 15, 20, 25)
$seed = 12345

Write-Host "Project root: $projectRoot"
Write-Host "Output directory: $outputDir"

foreach ($length in $lengths) {
    $random = [System.Random]::new($seed)
    $outputFile = Join-Path $outputDir "synthetic_L$length.txt"

    Write-Host "Creating dataset: L=$length"

    $writer = [System.IO.StreamWriter]::new(
        $outputFile,
        $false,
        [System.Text.Encoding]::ASCII
    )

    try {
        for ($t = 0; $t -lt $transactionCount; $t++) {
            # Tao item tu 1 den 100
            $items = [int[]](1..$itemUniverse)

            # Fisher-Yates shuffle
            for ($i = $itemUniverse - 1; $i -gt 0; $i--) {
                $j = $random.Next(0, $i + 1)

                $temp = $items[$i]
                $items[$i] = $items[$j]
                $items[$j] = $temp
            }

            # Lay L item dau tien va sap xep tang dan
            $transaction = @(
                $items[0..($length - 1)] | Sort-Object
            )

            # Ghi item dang so, cach nhau bang space
            $line = ($transaction -join " ")
            $writer.WriteLine($line)
        }
    }
    finally {
        $writer.Dispose()
    }

    Write-Host "Saved: $outputFile"
}

Write-Host "All synthetic datasets created."
