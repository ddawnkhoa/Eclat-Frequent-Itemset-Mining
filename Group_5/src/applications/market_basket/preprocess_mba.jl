using Random

function preprocess_groceries(raw_csv_path::String, spmf_out_path::String, map_out_path::String)
    Random.seed!(42)
    mkpath(dirname(spmf_out_path))
    mkpath(dirname(map_out_path))

    item_to_id = Dict{String, Int}()
    id_to_item = String[]
    transactions = Vector{Vector{Int}}()

    open(raw_csv_path, "r") do file
        for line in eachline(file)
            clean_line = strip(line)
            if isempty(clean_line)
                continue
            end
            transaction_ids = Int[]
            for raw_item in split(clean_line, ",")
                item_name = String(strip(raw_item))
                if isempty(item_name)
                    continue
                end
                if !haskey(item_to_id, item_name)
                    push!(id_to_item, item_name)
                    item_to_id[item_name] = length(id_to_item)
                end
                push!(transaction_ids, item_to_id[item_name])
            end
            unique!(sort!(transaction_ids))
            if !isempty(transaction_ids)
                push!(transactions, transaction_ids)
            end
        end
    end

    open(spmf_out_path, "w") do out_file
        for transaction in transactions
            println(out_file, join(transaction, " "))
        end
    end

    open(map_out_path, "w") do map_file
        println(map_file, "item_id,item_name")
        for (id, name) in enumerate(id_to_item)
            println(map_file, "$(id),\"$(name)\"")
        end
    end

    println("Transactions: $(length(transactions)), Items: $(length(id_to_item))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    preprocess_groceries(
        "data/market_basket/raw/groceries.csv",
        "data/market_basket/processed/mba_spmf.txt",
        "data/market_basket/processed/mba_item_map.csv"
    )
end