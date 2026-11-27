using Random
include("../../data_loader.jl")
include("../../structures_bitvector.jl")
include("../../algorithm/eclat_bitvector.jl")

function load_bio_map(map_path::String)::Dict{Int, String}
    mapping = Dict{Int, String}()
    open(map_path, "r") do file
        readline(file)
        for line in eachline(file)
            parts = split(line, ",", limit = 2)
            if length(parts) == 2
                mapping[parse(Int, strip(parts[1]))] = String(strip(parts[2]))
            end
        end
    end
    return mapping
end

function build_bit_database(transactions::Vector{Vector{Int}})::VerticalBitDB
    num_transactions::Int = length(transactions)
    item_set = Set{Int}()
    for transaction in transactions
        for item in transaction
            push!(item_set, item)
        end
    end
    sorted_items::Vector{Int} = sort!(collect(item_set))
    tidsets = Dict{Int, BitVector}(item => falses(num_transactions) for item in sorted_items)

    @inbounds for (tid, transaction) in enumerate(transactions)
        for item in transaction
            tidsets[item][tid] = true
        end
    end
    return VerticalBitDB(sorted_items, tidsets, num_transactions)
end

function run_biological_mining()
    Random.seed!(42)
    spmf_path = "data/biological/processed/bio_spmf.txt"
    map_path = "data/biological/processed/bio_item_map.csv"
    out_csv_path = "data/biological/outputs/bio_patterns.csv"
    mkpath(dirname(out_csv_path))

    transactions = load_spmf_file(spmf_path)
    total_transactions::Int = length(transactions)
    db = build_bit_database(transactions)

    minsup_count::Int = ceil(Int, 0.20 * total_transactions)
    raw_results = eclat_bitvector(db, minsup_count)
    frequent_itemsets = Dict{Vector{Int}, Int}(sort(items) => supp for (items, supp) in raw_results)

    bio_map = load_bio_map(map_path)
    patterns = [(ids, count) for (ids, count) in frequent_itemsets if length(ids) >= 2]
    sort!(patterns, by = item -> (item[2], length(item[1])), rev = true)

    open(out_csv_path, "w") do out_file
        println(out_file, "Rank,Pattern_Size,Biological_Motif,Support_Count,Support_Ratio")
        for (rank, (ids, count)) in enumerate(first(patterns, min(15, length(patterns))))
            motif_str = "{" * join([get(bio_map, id, string(id)) for id in ids], ", ") * "}"
            support_ratio = round(count / total_transactions, digits = 4)
            println(out_file, "$(rank),$(length(ids)),\"$(motif_str)\",$(count),$(support_ratio)")
            println("#$(rank) (k=$(length(ids))): $(motif_str) | Support = $(count)/$(total_transactions) ($(support_ratio))")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_biological_mining()
end