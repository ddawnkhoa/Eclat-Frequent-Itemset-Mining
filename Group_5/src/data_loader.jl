
# Đọc dữ liệu giao dịch theo định dạng SPMF
function load_spmf_file(filepath::String)
    if !isfile(filepath)
        throw(ArgumentError("Input file does not exist: $filepath"))
    end

    transactions = Vector{Vector{Int}}()

    open(filepath, "r") do file
        for (line_number, line) in enumerate(eachline(file))
            line = strip(line)

            # Bỏ qua dòng trống và metadata/comment
            if isempty(line) || startswith(line, "@") ||
               startswith(line, "#") || startswith(line, "%")
                continue
            end

            tokens = split(line)
            transaction = Int[]

            for token in tokens
                item = tryparse(Int, token)

                if item === nothing || item < 0
                    throw(ArgumentError(
                        "Invalid item at line $line_number: $token"
                    ))
                end

                push!(transaction, item)
            end

            # Sắp xếp và loại bỏ item trùng
            sort!(unique!(transaction))

            push!(transactions, transaction)
        end
    end

    return transactions
end
