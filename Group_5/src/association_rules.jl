
# ============================================================
# Association Rules - Market Basket Analysis
# Input: Frequent itemsets from Eclat BitVector
# ============================================================

"""
    build_support_dict(frequent_itemsets)
Eclat:
    Vector{Tuple{Vector{Int}, Int}}
    
to dictionary:
    Dict{Tuple, Int}

Key là itemset dạng Tuple đã được sắp xếp.
Value là support count.
"""
function build_support_dict(frequent_itemsets)
    supports = Dict{Tuple, Int}()

    for (items, support_count) in frequent_itemsets
        itemset = Tuple(sort(unique(items)))

        if isempty(itemset)
            continue
        end

        supports[itemset] = support_count
    end

    return supports
end


"""
    generate_association_rules(supports, ntransactions; minconf=0.30)

Sinh association rules X => Y từ frequent itemsets.

Các chỉ số:
- Support
- Confidence
- Lift

Chỉ giữ các luật có confidence >= minconf.
"""
function generate_association_rules(
    supports::Dict{Tuple, Int},
    ntransactions::Int;
    minconf::Float64 = 0.30
)
    if ntransactions <= 0
        throw(ArgumentError("ntransactions must be > 0"))
    end

    if !(0.0 <= minconf <= 1.0)
        throw(ArgumentError("minconf must be between 0 and 1"))
    end

    rules = NamedTuple[]

    for (itemset, union_count) in supports
        k = length(itemset)

        # Không thể sinh luật từ itemset chỉ có 1 item
        k < 2 && continue

        # Duyệt tất cả tập con không rỗng,
        # ngoại trừ chính itemset
        for mask in 1:((1 << k) - 2)

            antecedent = Tuple(
                itemset[i]
                for i in 1:k
                if (mask & (1 << (i - 1))) != 0
            )

            consequent = Tuple(
                itemset[i]
                for i in 1:k
                if (mask & (1 << (i - 1))) == 0
            )

            # Support count của X và Y
            if !haskey(supports, antecedent)
                throw(ArgumentError(
                    "Missing support count for antecedent $antecedent"
                ))
            end

            if !haskey(supports, consequent)
                throw(ArgumentError(
                    "Missing support count for consequent $consequent"
                ))
            end

            antecedent_count = supports[antecedent]
            consequent_count = supports[consequent]

            if antecedent_count == 0 || consequent_count == 0
                continue
            end

            # Tính các chỉ số
            support = union_count / ntransactions

            confidence = union_count / antecedent_count

            lift = confidence / (consequent_count / ntransactions)

            # Lọc theo MinConf
            if confidence >= minconf
                push!(rules, (
                    antecedent = antecedent,
                    consequent = consequent,
                    support_count = union_count,
                    support = support,
                    confidence = confidence,
                    lift = lift
                ))
            end
        end
    end

    # Sắp xếp Lift giảm dần.
    # Nếu Lift bằng nhau, ưu tiên Confidence cao hơn.
    sort!(rules, by = r -> (-r.lift, -r.confidence))

    return rules
end


"""
    top_association_rules(rules, k=10)

Lấy tối đa k luật có Lift cao nhất.
"""
function top_association_rules(rules, k::Int=10)
    if k < 0
        throw(ArgumentError("k must be >= 0"))
    end

    return rules[1:min(k, length(rules))]
end
