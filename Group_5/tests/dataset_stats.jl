include("../src/data_loader.jl")

function main()
    datasets = [
        "chess.txt",
        "mushroom.txt",
        "retail.txt",
        "T10I4D100K.txt"
    ]

    println("dataset,transactions,unique_items,total_items,avg_transaction_length")

    for filename in datasets
        path = joinpath("data", "benchmark", filename)
        transactions = load_spmf_file(path)

        ntransactions = length(transactions)
        all_items = Set{Int}()
        total_items = 0

        for transaction in transactions
            total_items += length(transaction)
            union!(all_items, transaction)
        end

        avg_length = ntransactions == 0 ? 0.0 :
                     total_items / ntransactions

        println(
            filename, ",",
            ntransactions, ",",
            length(all_items), ",",
            total_items, ",",
            avg_length
        )
    end
end

main()