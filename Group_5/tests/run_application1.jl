# Application 1: Market Basket Analysis
# Run from project root:
# julia --project=. tests/run_application1.jl

project_root = normpath(joinpath(@__DIR__, ".."))

include(joinpath(project_root, "src", "structures_bitvector.jl"))
include(joinpath(project_root, "src", "algorithm", "eclat_bitvector.jl"))
include(joinpath(project_root, "src", "association_rules.jl"))

# 1. Load transaction database

data_path = joinpath(
    project_root,
    "data",
    "benchmark",
    "retail.txt"
)

function load_retail_transactions(path::String)
    transactions = Vector{Vector{Int}}()

    for line in eachline(path)
        line = strip(line)

        # Bỏ qua dòng trống, không tính là transaction
        if isempty(line)
            continue
        end

        items = parse.(Int, split(line))

        # Mỗi transaction chỉ chứa item duy nhất
        push!(transactions, sort(unique(items)))
    end

    return transactions
end

transactions = load_retail_transactions(data_path)

ntransactions = length(transactions)


# 2. Set parameters

minsup_percent = 0.5
minconf = 0.60

minsup_count = ceil(
    Int,
    ntransactions * minsup_percent / 100
)


# 3. Convert horizontal database to vertical BitVector
db = build_vertical_bit_db(transactions)


# 4. Mine frequent itemsets using Eclat BitVector

frequent_itemsets = eclat_bitvector(db, minsup_count)
supports = build_support_dict(frequent_itemsets)

# 5. Generate association rules

rules = generate_association_rules(
    supports,
    ntransactions;
    minconf = minconf
)

top10 = top_association_rules(rules, 10)

# 6. Export results

output_dir = joinpath(project_root, "results", "application1")
mkpath(output_dir)

itemsets_path = joinpath(output_dir, "frequent_itemsets.csv")
rules_path = joinpath(output_dir, "association_rules.csv")

# Export frequent itemsets
open(itemsets_path, "w") do file
    println(file, "Itemset,SupportCount,Support")

    for (itemset, support_count) in frequent_itemsets
        itemset_text = join(itemset, " ")
        support = support_count / ntransactions

        println(
            file,
            "\"$itemset_text\",$support_count,$support"
        )
    end
end

# Export association rules
open(rules_path, "w") do file
    println(
        file,
        "Antecedent,Consequent,SupportCount,Support,Confidence,Lift"
    )

    for rule in rules
        antecedent_text = join(rule.antecedent, " ")
        consequent_text = join(rule.consequent, " ")

        println(
            file,
            "\"$antecedent_text\",",
            "\"$consequent_text\",",
            rule.support_count, ",",
            rule.support, ",",
            rule.confidence, ",",
            rule.lift
        )
    end
end

# 7. Display summary and Top 10 rules

println("\nAPPLICATION 1: Market Basket Analysis")
println("Dataset: Retail")
println("Transactions: ", ntransactions)
println("MinSup (%): ", minsup_percent)
println("MinSup count: ", minsup_count)
println("MinConf: ", minconf)
println("Frequent itemsets: ", length(frequent_itemsets))
println("Association rules: ", length(rules))

println("\nTop 10 Association Rules by Lift:")
println("--------------------------------------------------")

for (i, rule) in enumerate(top10)
    println(
        i, ". ",
        rule.antecedent, " => ", rule.consequent,
        " | Support = ", round(rule.support, digits=4),
        " | Confidence = ", round(rule.confidence, digits=4),
        " | Lift = ", round(rule.lift, digits=4)
    )
end

println("\nResults saved to:")
println(itemsets_path)
println(rules_path)