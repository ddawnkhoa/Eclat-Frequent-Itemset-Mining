include("structures.jl")
include("algorithm/eclat.jl")
include("data_loader.jl")
include("output.jl")

function main(args)
    if length(args) != 3
        println("Usage:")
        println("julia --project=. src/main.jl <input_file> <minsup> <output_file>")
        return
    end

    input_file = args[1]
    minsup = tryparse(Int, args[2])
    output_file = args[3]

    if minsup === nothing || minsup < 1
        println("Error: minsup must be a positive integer.")
        return
    end

    try
        # Đọc dữ liệu
        transactions = load_spmf_file(input_file)

        # Xây dựng Vertical Database
        db = build_vertical_db(transactions)

        # Chạy thuật toán Eclat
        results = eclat(db, minsup)

        # Xuất kết quả
        write_spmf_output(output_file, results)

        println("Mining completed successfully!")
        println("Transactions: ", db.ntransactions)
        println("Minimum support: ", minsup)
        println("Frequent itemsets: ", length(results))
        println("Output file: ", output_file)

    catch error
        println("Error: ", sprint(showerror, error))
    end
end

main(ARGS)
