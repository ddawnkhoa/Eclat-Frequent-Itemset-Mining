# Chay Eclat BitVector tren dataset protein (Application 2).
# julia .\tests\run_application2.jl

projectRoot = dirname(@__DIR__)

mainPath = joinpath(projectRoot, "src", "main.jl")
transactionPath = joinpath(
    projectRoot, "data", "application2", "protein_transactions.txt"
)
resultsDir = joinpath(projectRoot, "data", "application2")

# Cac nguong MinSup (%) can benchmark
minsupValues = [20, 25, 30, 35, 40]

# Kiem tra cac file dau vao
if !isfile(mainPath)
    error("Khong tim thay main.jl: $mainPath")
end

if !isfile(transactionPath)
    error("Khong tim thay transaction file: $transactionPath")
end

mkpath(resultsDir)

println("=== APPLICATION 2: PROTEIN MINING ===")
println("Input: ", transactionPath)
println("Algorithm: BitVector")
println("MinSup values: ", minsupValues)
println()

for minsup in minsupValues
    outputPath = joinpath(
        resultsDir,
        "frequent_itemsets_minsup$(minsup).txt"
    )

    println("----------------------------------------")
    println("Running Eclat with MinSup = ", minsup, "%")
    println("Output: ", outputPath)

    # Dung cung Julia executable dang chay script nay.
    # Cmd interpolation tu dong quote duong dan co khoang trang tren Windows.
    cmd = `$(Base.julia_cmd()) $mainPath $transactionPath $minsup $outputPath bitvector`

    run(cmd)

    println("Completed MinSup = ", minsup, "%")
    println()
end

println("=== ALL APPLICATION 2 RUNS COMPLETED ===")
println("Results directory: ", resultsDir)
