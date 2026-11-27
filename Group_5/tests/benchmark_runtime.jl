# tests/benchmark_runtime.ps1

$datasets = @(
    # "chess.txt"
    # "mushroom.txt"
    # "retail.txt"
    "T10I4D100K.txt"
)

$percentages = @(5,4,3,2,1)
$repeats = 3

$inputDir = "data/benchmark"
$outputDir = "data/benchmark"
$resultsDir = "results/runtime"

New-Item -ItemType Directory -Force $resultsDir | Out-Null

$csvFile = Join-Path $resultsDir "julia_runtime.csv"

# Schema CSV thống nhất với SPMF
$columns = @(
    "Dataset",
    "Transactions",
    "MinsupPercent",
    "MinsupCount",
    "Algorithm",
    "Repeats",
    "Run1Sec",
    "Run2Sec",
    "Run3Sec",
    "MedianSec"
)

# Kiểm tra header nếu CSV đã tồn tại
if (Test-Path $csvFile) {
    $existingHeader = (Get-Content $csvFile -TotalCount 1).Trim()
    $expectedHeader = ($columns | ForEach-Object {
        '"' + $_ + '"'
    }) -join ","

    if ($existingHeader -ne $expectedHeader) {
        Write-Error "CSV hiện tại không đúng schema mới."
        Write-Error "Hãy đổi tên hoặc xóa file: $csvFile"
        exit 1
    }
}

$results = @()

foreach ($dataset in $datasets) {

    $inputFile = Join-Path $inputDir $dataset
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($dataset)

    if (-not (Test-Path $inputFile)) {
        Write-Warning "Dataset not found: $inputFile"
        continue
    }

    # Đếm số giao dịch
    $N = (Get-Content $inputFile | Where-Object {
        $_.Trim() -ne "" -and $_ -notmatch '^\s*[@#%]'
    }).Count

    Write-Host "`nDataset: $dataset, Transactions: $N"

    foreach ($percent in $percentages) {

        # Tính minsup count để lưu vào CSV
        $minsup = [math]::Ceiling($N * $percent / 100)

        # Output file riêng cho từng dataset và minsup
        $outputFile = Join-Path $outputDir "${baseName}_julia_${percent}.txt"

        $times = @()

        for ($run = 1; $run -le $repeats; $run++) {

            Write-Host "MinSup $percent% (count=$minsup), run $run/$repeats"

            $elapsed = (Measure-Command {
                & julia --project=. src/main.jl `
                    $inputFile $percent $outputFile bitvector
            }).TotalSeconds

            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Julia failed: $dataset minsup=$percent run=$run"
                continue
            }

            $times += [double]$elapsed
        }

        if ($times.Count -eq 0) {
            Write-Warning "No successful runs for $dataset minsup=$percent"
            continue
        }

        # Tính median runtime
        $sortedTimes = @($times | Sort-Object)
        $count = $sortedTimes.Count

        if ($count % 2 -eq 1) {
            $medianTime = $sortedTimes[[int](($count - 1) / 2)]
        }
        else {
            $middle1 = $sortedTimes[($count / 2) - 1]
            $middle2 = $sortedTimes[$count / 2]
            $medianTime = ($middle1 + $middle2) / 2
        }

        # Lấy thời gian từng lần chạy
        $run1 = if ($times.Count -ge 1) { $times[0] } else { $null }
        $run2 = if ($times.Count -ge 2) { $times[1] } else { $null }
        $run3 = if ($times.Count -ge 3) { $times[2] } else { $null }

        # Tạo dòng kết quả
        $results += [PSCustomObject]@{
            Dataset       = $baseName
            Transactions  = $N
            MinsupPercent = $percent
            MinsupCount   = $minsup
            Algorithm     = "Julia BitVector"
            Repeats       = $times.Count
            Run1Sec       = if ($null -ne $run1) { [math]::Round($run1, 4) } else { $null }
            Run2Sec       = if ($null -ne $run2) { [math]::Round($run2, 4) } else { $null }
            Run3Sec       = if ($null -ne $run3) { [math]::Round($run3, 4) } else { $null }
            MedianSec     = [math]::Round($medianTime, 4)
        }

        Write-Host "Median runtime: $([math]::Round($medianTime, 4)) seconds"
    }
}

# Ghi CSV: append nếu đã tồn tại, tạo mới nếu chưa tồn tại
if ($results.Count -gt 0) {

    $orderedResults = $results | Select-Object $columns

    if (Test-Path $csvFile) {

        $orderedResults |
            Export-Csv $csvFile -NoTypeInformation -Encoding UTF8 -Append

        Write-Host "`nAppended results to $csvFile"

    }
    else {

        $orderedResults |
            Export-Csv $csvFile -NoTypeInformation -Encoding UTF8

        Write-Host "`nCreated results file: $csvFile"
    }

}
else {
    Write-Warning "No results to write."
}
