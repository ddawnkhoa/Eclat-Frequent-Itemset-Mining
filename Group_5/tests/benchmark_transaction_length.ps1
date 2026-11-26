# tests/benchmark_transaction_length.ps1
# Benchmark anh huong do dai giao dich tren synthetic datasets L5-L25.
# Chay duoc tu bat ky thu muc nao.

$ErrorActionPreference = "Stop"

# Xac dinh project root tu vi tri file script: tests/ -> project root
$projectRoot = Split-Path -Parent $PSScriptRoot
$benchmarkDir = Join-Path $projectRoot "data\benchmark\transaction_length"
$resultsDir = Join-Path $projectRoot "results\transaction_length"
$csvFile = Join-Path $resultsDir "transaction_length_runtime.csv"

$lengths = @(5, 10, 15, 20, 25)
$repeats = 3
$minsupPercent = 5
$algorithmName = "Julia BitVector"
$algorithmCli = "bitvector"

$columns = @(
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
    "MaxSec"
)

New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null

# Kiem tra schema CSV neu file da ton tai
if (Test-Path $csvFile) {
    $existingHeader = (Get-Content $csvFile -TotalCount 1).Trim()
    $expectedHeader = ($columns | ForEach-Object { '"' + $_ + '"' }) -join ","

    if ($existingHeader -ne $expectedHeader) {
        throw "CSV co schema khac. Hay doi ten/xoa file truoc khi chay: $csvFile"
    }
}

$results = @()

Push-Location $projectRoot
try {
    foreach ($length in $lengths) {
        $datasetName = "Synthetic-L$length"
        $inputFile = Join-Path $benchmarkDir "synthetic_L$length.txt"

        if (-not (Test-Path $inputFile)) {
            Write-Warning "Khong tim thay dataset: $inputFile. Bo qua."
            continue
        }

        # Dem so giao dich thuc te, tranh dung nham N
        $transactionCount = (Get-Content -Path $inputFile | Measure-Object -Line).Lines

        if ($transactionCount -le 0) {
            Write-Warning "Dataset rong: $inputFile. Bo qua."
            continue
        }

        $minsupCount = [int][math]::Ceiling(
            $transactionCount * $minsupPercent / 100.0
        )

        $outputFile = Join-Path $benchmarkDir "result_L${length}_bitvector.txt"

        Write-Host ""
        Write-Host "=========================================="
        Write-Host "$datasetName"
        Write-Host "Transactions : $transactionCount"
        Write-Host "Avg length  : $length"
        Write-Host "MinSup      : $minsupPercent% ($minsupCount)"
        Write-Host "Algorithm   : $algorithmName"
        Write-Host "=========================================="

        $times = @()

        for ($run = 1; $run -le $repeats; $run++) {
            Write-Host "$algorithmName - run $run/$repeats"

            $timer = [System.Diagnostics.Stopwatch]::StartNew()

            & julia --project=. src/main.jl `
                $inputFile `
                $minsupPercent `
                $outputFile `
                $algorithmCli *> $null

            $exitCode = $LASTEXITCODE
            $timer.Stop()

            if ($exitCode -ne 0) {
                Write-Warning "Julia failed: $datasetName / run $run (exit code $exitCode)"
                continue
            }

            $seconds = [math]::Round($timer.Elapsed.TotalSeconds, 4)
            $times += $seconds
            Write-Host "Runtime: $seconds sec"
        }

        if ($times.Count -eq 0) {
            Write-Warning "Khong co run thanh cong cho $datasetName."
            continue
        }

        $sortedTimes = @($times | Sort-Object)
        $count = $sortedTimes.Count

        if (($count % 2) -eq 1) {
            $median = $sortedTimes[[int][math]::Floor($count / 2)]
        }
        else {
            $median = (
                $sortedTimes[($count / 2) - 1] +
                $sortedTimes[$count / 2]
            ) / 2.0
        }

        $maximum = ($times | Measure-Object -Maximum).Maximum

        $run1 = $null
        $run2 = $null
        $run3 = $null
        if ($times.Count -ge 1) { $run1 = $times[0] }
        if ($times.Count -ge 2) { $run2 = $times[1] }
        if ($times.Count -ge 3) { $run3 = $times[2] }

        $results += [PSCustomObject]@{
            Dataset                = $datasetName
            AvgTransactionLength   = $length
            Transactions           = $transactionCount
            MinSupPercent          = $minsupPercent
            MinSupCount            = $minsupCount
            Algorithm               = $algorithmName
            Repeats                 = $times.Count
            Run1Sec                 = $run1
            Run2Sec                 = $run2
            Run3Sec                 = $run3
            MedianSec               = [math]::Round($median, 4)
            MaxSec                  = [math]::Round($maximum, 4)
        }

        Write-Host "Median runtime: $([math]::Round($median, 4)) sec"
    }
}
finally {
    Pop-Location
}

if ($results.Count -gt 0) {
    $orderedResults = $results | Select-Object $columns

    if (Test-Path $csvFile) {
        $orderedResults | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8 -Append
        Write-Host ""
        Write-Host "Appended CSV: $csvFile"
    }
    else {
        $orderedResults | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Host ""
        Write-Host "Created CSV: $csvFile"
    }
}
else {
    Write-Warning "Khong co ket qua nao de ghi CSV."
}

Write-Host ""
Write-Host "Benchmark transaction length completed."
