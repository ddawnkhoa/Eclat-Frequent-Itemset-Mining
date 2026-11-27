module AssociationRules

export AssociationRule, generate_rules

struct AssociationRule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    support::Float64
    confidence::Float64
    lift::Float64
end

function get_proper_subsets(itemset::Vector{Int})::Vector{Vector{Int}}
    n::Int = length(itemset)
    subsets = Vector{Vector{Int}}()
    sizehint!(subsets, (1 << n) - 2)
    for mask in 1:((1 << n) - 2)
        subset = Int[]
        @inbounds for i in 1:n
            if (mask & (1 << (i - 1))) != 0
                push!(subset, itemset[i])
            end
        end
        push!(subsets, subset)
    end
    return subsets
end

function generate_rules(
    frequent_itemsets::Dict{Vector{Int}, Int},
    total_transactions::Int,
    minconf::Float64
)::Vector{AssociationRule}
    rules = AssociationRule[]
    if total_transactions <= 0
        return rules
    end

    for (itemset, support_x_count) in frequent_itemsets
        if length(itemset) < 2
            continue
        end
        sorted_itemset::Vector{Int} = sort(itemset)
        for antecedent in get_proper_subsets(sorted_itemset)
            consequent::Vector{Int} = setdiff(sorted_itemset, antecedent)
            support_a_count::Int = get(frequent_itemsets, antecedent, 0)
            support_b_count::Int = get(frequent_itemsets, consequent, 0)

            if support_a_count == 0 || support_b_count == 0
                continue
            end

            confidence::Float64 = support_x_count / support_a_count
            if confidence >= minconf
                support::Float64 = support_x_count / total_transactions
                support_b::Float64 = support_b_count / total_transactions
                lift::Float64 = confidence / support_b
                push!(rules, AssociationRule(antecedent, consequent, support, confidence, lift))
            end
        end
    end

    sort!(rules, by = rule -> (rule.lift, rule.confidence, rule.support), rev = true)
    return rules
end

end