# tests/benchmark_memory.ps1
# Chay tai thu muc goc project bang PowerShell.
# Do Peak Working Set (RAM peak) cua Julia cho Vector va BitVector.

$ErrorActionPreference = "Stop"

$inputDir = "data/benchmark"
$outputDir = "data/benchmark"
$resultsDir = "results/memory"
$csvFile = Join-Path $resultsDir "memory_runtime.csv"
$repeats = 3

# MinSup trung binh trong cac day benchmark
$testCases = @(
    @{ Dataset = "chess";      Transactions = 3196;   MinSupPercent = 60 },
    @{ Dataset = "mushroom";   Transactions = 8124;   MinSupPercent = 30 },
    @{ Dataset = "retail";     Transactions = 88162;  MinSupPercent = 3 },
    @{ Dataset = "T10I4D100K"; Transactions = 100000; MinSupPercent = 3 }
)

# CLI algorithm key phai khop voi src/main.jl
$algorithms = @(
    @{ Name = "Julia Vector";    Cli = "vector" },
    @{ Name = "Julia BitVector"; Cli = "bitvector" }
)

New-Item -ItemType Directory -Force $resultsDir | Out-Null

$columns = @(
    "Dataset", "Transactions", "MinsupPercent", "MinsupCount",
    "Algorithm", "Repeats",
    "Run1PeakRAM_MB", "Run2PeakRAM_MB", "Run3PeakRAM_MB",
    "MedianPeakRAM_MB", "MaxPeakRAM_MB"
)

# Kiem tra header CSV neu file da ton tai
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
    $dataset = $case.Dataset
    $N = [int]$case.Transactions
    $percent = [int]$case.MinSupPercent
    $inputFile = Join-Path $inputDir ($dataset + ".txt")
    $minsupCount = [math]::Ceiling($N * $percent / 100)

    if (-not (Test-Path $inputFile)) {
        Write-Warning "Khong tim thay dataset: $inputFile"
        continue
    }

    Write-Host ""
    Write-Host "Dataset: $dataset | MinSup: $percent% | Count: $minsupCount"

    foreach ($algorithm in $algorithms) {
        $algorithmName = $algorithm.Name
        $algorithmCli = $algorithm.Cli
        $outputFile = Join-Path $outputDir ($dataset + "_julia_" + $percent + "_" + $algorithmCli + ".txt")
        $peakValuesMB = @()

        for ($run = 1; $run -le $repeats; $run++) {
            Write-Host "$algorithmName - run $run/$repeats"

            $argumentList = @(
                "--project=.",
                "src/main.jl",
                $inputFile,
                [string]$percent,
                $outputFile,
                $algorithmCli
            )

            $process = Start-Process -FilePath "julia" `
                -ArgumentList $argumentList `
                -PassThru `
                -WindowStyle Hidden
            $peakBytes = 0.0

            while (-not $process.HasExited) {
                try {
                    $process.Refresh()
                    $value = [double]$process.PeakWorkingSet64
                    if ($value -gt $peakBytes) {
                        $peakBytes = $value
                    }
                }
                catch {
                    # Process can exit while reading its metrics.
                }
                Start-Sleep -Milliseconds 50
            }

            try {
                $process.Refresh()
                $value = [double]$process.PeakWorkingSet64
                if ($value -gt $peakBytes) {
                    $peakBytes = $value
                }
            }
            catch {
                # Use peak captured while polling.
            }

            if ($process.ExitCode -ne 0) {
                Write-Warning "Julia failed: $dataset / $algorithmCli / run $run"
                continue
            }

            if ($peakBytes -le 0) {
                Write-Warning "Could not read peak working set."
                continue
            }

            $peakMB = [math]::Round($peakBytes / 1MB, 2)
            $peakValuesMB += $peakMB
            Write-Host "Peak RAM: $peakMB MB"
        }

        if ($peakValuesMB.Count -eq 0) {
            Write-Warning "No successful runs: $dataset / $algorithmCli"
            continue
        }

        $sortedPeaks = @($peakValuesMB | Sort-Object)
        $valueCount = $sortedPeaks.Count

        if (($valueCount % 2) -eq 1) {
            $medianPeak = $sortedPeaks[[int](($valueCount - 1) / 2)]
        }
        else {
            $left = $sortedPeaks[($valueCount / 2) - 1]
            $right = $sortedPeaks[$valueCount / 2]
            $medianPeak = ($left + $right) / 2
        }

        $maxPeak = ($peakValuesMB | Measure-Object -Maximum).Maximum

        $run1 = $null
        $run2 = $null
        $run3 = $null
        if ($peakValuesMB.Count -ge 1) { $run1 = $peakValuesMB[0] }
        if ($peakValuesMB.Count -ge 2) { $run2 = $peakValuesMB[1] }
        if ($peakValuesMB.Count -ge 3) { $run3 = $peakValuesMB[2] }

        $results += [PSCustomObject]@{
            Dataset          = $dataset
            Transactions     = $N
            MinsupPercent    = $percent
            MinsupCount      = $minsupCount
            Algorithm        = $algorithmName
            Repeats          = $peakValuesMB.Count
            Run1PeakRAM_MB   = $run1
            Run2PeakRAM_MB   = $run2
            Run3PeakRAM_MB   = $run3
            MedianPeakRAM_MB = [math]::Round($medianPeak, 2)
            MaxPeakRAM_MB    = [math]::Round($maxPeak, 2)
        }

        Write-Host "Median peak RAM: $([math]::Round($medianPeak, 2)) MB"
        Write-Host "Maximum peak RAM: $([math]::Round($maxPeak, 2)) MB"
    }
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
