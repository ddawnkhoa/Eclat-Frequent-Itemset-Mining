using Random
include("../../data_loader.jl")
include("../../structures_bitvector.jl")
include("../../algorithm/eclat_bitvector.jl")
include("../../algorithm/rules.jl")
using .AssociationRules

function load_item_map(map_path::String)::Dict{Int, String}
    mapping = Dict{Int, String}()
    open(map_path, "r") do file
        readline(file)
        for line in eachline(file)
            parts = split(line, ",", limit = 2)
            if length(parts) == 2
                mapping[parse(Int, strip(parts[1]))] = replace(strip(parts[2]), "\"" => "")
            end
        end
    end
    return mapping
end

function format_items(ids::Vector{Int}, mapping::Dict{Int, String})::String
    return "{" * join([get(mapping, id, string(id)) for id in ids], ", ") * "}"
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

function run_market_basket_analysis()
    Random.seed!(42)
    spmf_path = "data/market_basket/processed/mba_spmf.txt"
    map_path = "data/market_basket/processed/mba_item_map.csv"
    out_csv_path = "data/market_basket/outputs/top10_rules.csv"
    mkpath(dirname(out_csv_path))

    transactions = load_spmf_file(spmf_path)
    total_transactions::Int = length(transactions)
    db = build_bit_database(transactions)

    minsup_count::Int = ceil(Int, 0.01 * total_transactions)
    minconf_ratio::Float64 = 0.30

    raw_results = eclat_bitvector(db, minsup_count)
    frequent_itemsets = Dict{Vector{Int}, Int}(sort(items) => supp for (items, supp) in raw_results)

    rules = generate_rules(frequent_itemsets, total_transactions, minconf_ratio)
    top10_rules = first(rules, min(10, length(rules)))
    item_map = load_item_map(map_path)

    open(out_csv_path, "w") do out_file
        println(out_file, "Rank,Antecedent,Consequent,Support,Confidence,Lift")
        for (rank, rule) in enumerate(top10_rules)
            antecedent_str = format_items(rule.antecedent, item_map)
            consequent_str = format_items(rule.consequent, item_map)
            supp_val = round(rule.support, digits = 4)
            conf_val = round(rule.confidence, digits = 4)
            lift_val = round(rule.lift, digits = 4)
            println(out_file, "$(rank),\"$(antecedent_str)\",\"$(consequent_str)\",$(supp_val),$(conf_val),$(lift_val)")
            println("#$(rank): $(antecedent_str) => $(consequent_str) | Supp=$(supp_val), Conf=$(conf_val), Lift=$(lift_val)")
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_market_basket_analysis()
end