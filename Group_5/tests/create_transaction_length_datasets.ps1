
# tests/create_transaction_length_datasets.ps1
# Tao synthetic datasets cho benchmark transaction length.
# Chay duoc tu bat ky thu muc nao.

$ErrorActionPreference = "Stop"

# tests/ -> project root
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
