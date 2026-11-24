# Cấu trúc lưu trữ cơ sở dữ liệu theo chiều dọc
struct VerticalDB
    items::Vector{Int}
    tidsets::Dict{Int, Vector{Int}}
    ntransactions::Int
end

# Chuyển cơ sở dữ liệu ngang sang Vertical Database
function build_vertical_db(transactions::Vector{Vector{Int}})
    tidsets = Dict{Int, Vector{Int}}()

    for (tid, transaction) in enumerate(transactions)
        # Mỗi item chỉ xuất hiện một lần trong một transaction
        for item in unique(transaction)
            if !haskey(tidsets, item)
                tidsets[item] = Int[]
            end

            push!(tidsets[item], tid)
        end
    end

    items = sort(collect(keys(tidsets)))

    return VerticalDB(items, tidsets, length(transactions))
end
