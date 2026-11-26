# tests/benchmark_scalability.ps1
# Chay tai thu muc goc project.
# Benchmark scalability Retail voi Julia BitVector.
# Dataset subset va file ket qua .txt deu nam truc tiep trong data/benchmark.
# Do thoi gian chay 3 lan cho moi kich thuoc dataset.

$ErrorActionPreference = "Stop"

$benchmarkDir = "data/benchmark"
$resultsDir = "results/scalability"
$csvFile = Join-Path $resultsDir "scalability_runtime.csv"

$repeats = 3
$minsupPercent = 3
$algorithmName = "Julia BitVector"
$algorithmCli = "bitvector"

# So giao dich: Floor(88162 * percentage / 100)
$testCases = @(
    @{ Percent = 10;  N = 8816  },
    @{ Percent = 25;  N = 22040 },
    @{ Percent = 50;  N = 44081 },
    @{ Percent = 75;  N = 66121 },
    @{ Percent = 100; N = 88162 }
)

New-Item -ItemType Directory -Force $resultsDir | Out-Null

$columns = @(
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
    "MaxSec"
)

# Kiem tra header CSV neu file da ton tai.
if (Test-Path $csvFile) {
    $existingHeader = (Get-Content $csvFile -TotalCount 1).Trim()
    $expectedHeader = ($columns | ForEach-Object { '"' + $_ + '"' }) -join ","

    if ($existingHeader -ne $expectedHeader) {
        Write-Error "CSV co schema khac. Hay doi ten/xoa file: $csvFile"
        exit 1
    }
}

$results = @()

foreach ($case in $testCases) {
    $percent = [int]$case.Percent
    $N = [int]$case.N
    $minsupCount = [int][math]::Ceiling($N * $minsupPercent / 100)

    # Cac file subset retail_10.txt, retail_25.txt, ... nam trong data/benchmark.
    $inputFile = Join-Path $benchmarkDir "retail_${percent}.txt"

    if (-not (Test-Path $inputFile)) {
        Write-Warning "Khong tim thay dataset: $inputFile"
        continue
    }

    # Xac minh so giao dich thuc te trong file subset.
    $actualN = (Get-Content $inputFile | Measure-Object -Line).Lines

    if ($actualN -ne $N) {
        Write-Warning "So giao dich trong $inputFile la $actualN, expected $N. Dung so thuc te."
        $N = [int]$actualN
        $minsupCount = [int][math]::Ceiling($N * $minsupPercent / 100)
    }

    Write-Host ""
    Write-Host "Retail $percent% | Transactions: $N | MinSup: $minsupPercent% ($minsupCount)"

    $times = @()

    # File ket qua itemset .txt duoc xuat truc tiep vao data/benchmark.
    $outputFile = Join-Path $benchmarkDir "retail_${percent}_julia_bitvector.txt"

    for ($run = 1; $run -le $repeats; $run++) {
        Write-Host "$algorithmName - run $run/$repeats"

        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        # Goi Julia truc tiep, khong mo terminal rieng.
        & julia --project=. src/main.jl `
            $inputFile `
            $minsupPercent `
            $outputFile `
            $algorithmCli *> $null

        $exitCode = $LASTEXITCODE
        $timer.Stop()

        if ($exitCode -ne 0) {
            Write-Warning "Julia failed: Retail $percent% / run $run (exit code $exitCode)"
            continue
        }

        $seconds = [math]::Round($timer.Elapsed.TotalSeconds, 4)
        $times += $seconds

        Write-Host "Runtime: $seconds sec"
    }

    if ($times.Count -eq 0) {
        Write-Warning "No successful runs for Retail $percent%."
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
        ) / 2
    }

    $maximum = ($times | Measure-Object -Maximum).Maximum

    $run1 = $null
    $run2 = $null
    $run3 = $null

    if ($times.Count -ge 1) { $run1 = $times[0] }
    if ($times.Count -ge 2) { $run2 = $times[1] }
    if ($times.Count -ge 3) { $run3 = $times[2] }

    $results += [PSCustomObject]@{
        Dataset        = "Retail"
        DatasetPercent = $percent
        Transactions   = $N
        MinsupPercent  = $minsupPercent
        MinsupCount    = $minsupCount
        Algorithm      = $algorithmName
        Repeats        = $times.Count
        Run1Sec        = $run1
        Run2Sec        = $run2
        Run3Sec        = $run3
        MedianSec      = [math]::Round($median, 4)
        MaxSec         = [math]::Round($maximum, 4)
    }

    Write-Host "Median runtime: $([math]::Round($median, 4)) sec"
    Write-Host "Maximum runtime: $([math]::Round($maximum, 4)) sec"
}

if ($results.Count -gt 0) {
    $orderedResults = $results | Select-Object $columns

    if (Test-Path $csvFile) {
        $orderedResults | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8 -Append
        Write-Host ""
        Write-Host "Appended results: $csvFile"
    }
    else {
        $orderedResults | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
        Write-Host ""
        Write-Host "Created CSV: $csvFile"
    }
}
else {
    Write-Warning "No results to write."
}
