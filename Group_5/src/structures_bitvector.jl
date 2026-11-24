# Vertical Database sử dụng BitVector
struct VerticalBitDB
    items::Vector{Int}
    tidsets::Dict{Int, BitVector}
    ntransactions::Int
end

# Chuyển cơ sở dữ liệu ngang sang dạng Vertical BitVector
function build_vertical_bit_db(transactions::Vector{Vector{Int}})
    ntransactions = length(transactions)

    tidsets = Dict{Int, BitVector}()

    for (tid, transaction) in enumerate(transactions)
        for item in unique(transaction)
            if !haskey(tidsets, item)
                tidsets[item] = falses(ntransactions)
            end

            # Đánh dấu item xuất hiện trong transaction này
            tidsets[item][tid] = true
        end
    end

    items = sort(collect(keys(tidsets)))

    return VerticalBitDB(items, tidsets, ntransactions)
end
