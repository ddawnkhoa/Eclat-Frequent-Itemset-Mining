# Thuật toán Eclat sử dụng BitVector

function eclat_bitvector(db::VerticalBitDB, minsup::Int)
    if minsup < 1
        throw(ArgumentError("minsup must be >= 1"))
    end

    results = Tuple{Vector{Int}, Int}[]

    # Lọc các item không đạt minsup
    initial = Tuple{Int, BitVector}[]

    for item in db.items
        tids = db.tidsets[item]
        support = count(identity, tids)

        if support >= minsup
            push!(initial, (item, tids))
        end
    end

    # Hàm khai thác đệ quy
    function extend(prefix, extensions)
        for i in eachindex(extensions)
            item, tids = extensions[i]

            new_prefix = [prefix; item]

            # Support là số bit có giá trị true
            support = count(identity, tids)

            push!(results, (new_prefix, support))

            # Tạo các phần mở rộng tiếp theo
            suffix = Tuple{Int, BitVector}[]

            for j in (i + 1):length(extensions)
                next_item, next_tids = extensions[j]

                # Giao hai TID-set bằng phép AND
                common_tids = tids .& next_tids

                common_support = count(identity, common_tids)

                if common_support >= minsup
                    push!(suffix, (next_item, common_tids))
                end
            end

            extend(new_prefix, suffix)
        end
    end

    extend(Int[], initial)

    return results
end
