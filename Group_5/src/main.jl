include(joinpath(@__DIR__, "structures.jl"))
include(joinpath(@__DIR__, "structures_bitvector.jl"))
include(joinpath(@__DIR__, "algorithm", "eclat.jl"))
include(joinpath(@__DIR__, "algorithm", "eclat_bitvector.jl"))
include(joinpath(@__DIR__, "data_loader.jl"))
include(joinpath(@__DIR__, "output.jl"))

function main(args)

    # Kiểm tra số lượng tham số
    if length(args) < 3 || length(args) > 4
        println("Usage:")
        println("julia --project=. src/main.jl <input_file> <minsup_percent> <output_file> [algorithm]")
        println()
        println("minsup_percent: minimum support percentage (1-100)")
        println()
        println("Algorithms:")
        println("  vector     Eclat using Vector{Int} (default)")
        println("  bitvector  Eclat using BitVector")
        return
    end

    input_file = args[1]
    minsup_percent = tryparse(Float64, args[2])
    output_file = args[3]

    # Thuật toán mặc định
    algorithm = length(args) == 4 ? lowercase(args[4]) : "vector"

    # Kiểm tra minsup percentage
    if minsup_percent === nothing ||
       !isfinite(minsup_percent) ||
       minsup_percent <= 0 ||
       minsup_percent > 100

        println("Error: minsup_percent must be in range (0, 100].")
        return
    end

    # Kiểm tra thuật toán
    if !(algorithm in ["vector", "bitvector"])
        println("Error: Unknown algorithm '$algorithm'.")
        println("Available algorithms: vector, bitvector")
        return
    end

    try
        # Đọc dữ liệu
        transactions = load_spmf_file(input_file)
        ntransactions = length(transactions)

        if ntransactions == 0
            println("Error: Input dataset is empty.")
            return
        end

        # Chuyển minsup percentage thành support count
        minsup_count = ceil(Int, ntransactions * minsup_percent / 100)

        # Chạy thuật toán được lựa chọn
        if algorithm == "vector"

            db = build_vertical_db(transactions)
            results = eclat(db, minsup_count)

        else

            db = build_vertical_bit_db(transactions)
            results = eclat_bitvector(db, minsup_count)

        end

        # Xuất kết quả
        write_spmf_output(output_file, results)

        println("Mining completed successfully!")
        println("Algorithm: ", algorithm)
        println("Transactions: ", ntransactions)
        println("Minimum support (%): ", minsup_percent)
        println("Minimum support count: ", minsup_count)
        println("Frequent itemsets: ", length(results))
        println("Output file: ", output_file)

    catch error
        println("Error: ", sprint(showerror, error))
    end
end

main(ARGS)
