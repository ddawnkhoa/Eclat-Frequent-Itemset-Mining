# Tính giao hai TID-set đã được sắp xếp tăng dần
function tidset_intersection(a::Vector{Int}, b::Vector{Int})
    result = Int[]

    i = 1
    j = 1

    while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            push!(result, a[i])
            i += 1
            j += 1
        elseif a[i] < b[j]
            i += 1
        else
            j += 1
        end
    end

    return result
end


# Thuật toán Eclat
function eclat(db::VerticalDB, minsup::Int)
    if minsup < 1
        throw(ArgumentError("minsup must be >= 1"))
    end

    # Lưu kết quả dưới dạng (itemset, support)
    results = Tuple{Vector{Int}, Int}[]

    # Lọc các item không đạt minsup
    initial = Tuple{Int, Vector{Int}}[]

    for item in db.items
        tids = db.tidsets[item]

        if length(tids) >= minsup
            push!(initial, (item, tids))
        end
    end

    # Hàm khai thác đệ quy
    function extend(prefix, extensions)
        for i in eachindex(extensions)
            item, tids = extensions[i]

            # Tạo itemset mới
            new_prefix = [prefix; item]

            # Support = số TID trong TID-set
            support = length(tids)

            push!(results, (new_prefix, support))

            # Tạo các phần mở rộng tiếp theo
            suffix = Tuple{Int, Vector{Int}}[]

            for j in (i + 1):length(extensions)
                next_item, next_tids = extensions[j]

                common_tids = tidset_intersection(tids, next_tids)

                if length(common_tids) >= minsup
                    push!(suffix, (next_item, common_tids))
                end
            end

            # Tiếp tục khai thác
            extend(new_prefix, suffix)
        end
    end

    extend(Int[], initial)

    return results
end
