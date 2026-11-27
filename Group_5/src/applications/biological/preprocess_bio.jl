using Random

function preprocess_promoter_sequences(raw_data_path::String, spmf_out_path::String, map_out_path::String)
    Random.seed!(42)
    mkpath(dirname(spmf_out_path))
    mkpath(dirname(map_out_path))

    feature_to_id = Dict{String, Int}()
    id_to_feature = String[]
    transactions = Vector{Vector{Int}}()

    open(raw_data_path, "r") do file
        for line in eachline(file)
            clean_line = strip(line)
            if isempty(clean_line)
                continue
            end
            parts = split(clean_line, ",")
            if length(parts) < 3
                continue
            end
            if strip(parts[1]) != "+"
                continue
            end

            sequence = uppercase(replace(strip(parts[3]), r"\s+" => ""))
            transaction_ids = Int[]

            for (index, nucleotide) in enumerate(sequence)
                bio_position::Int = index <= 50 ? (index - 51) : (index - 50)
                feature_name = "Pos_$(bio_position)_$(nucleotide)"
                if !haskey(feature_to_id, feature_name)
                    push!(id_to_feature, feature_name)
                    feature_to_id[feature_name] = length(id_to_feature)
                end
                push!(transaction_ids, feature_to_id[feature_name])
            end

            unique!(sort!(transaction_ids))
            push!(transactions, transaction_ids)
        end
    end

    open(spmf_out_path, "w") do out_file
        for transaction in transactions
            println(out_file, join(transaction, " "))
        end
    end

    open(map_out_path, "w") do map_file
        println(map_file, "item_id,biological_feature")
        for (id, feature) in enumerate(id_to_feature)
            println(map_file, "$(id),$(feature)")
        end
    end

    println("Sequences: $(length(transactions)), Features: $(length(id_to_feature))")
end

if abspath(PROGRAM_FILE) == @__FILE__
    preprocess_promoter_sequences(
        "data/biological/raw/promoters.data",
        "data/biological/processed/bio_spmf.txt",
        "data/biological/processed/bio_item_map.csv"
    )
end