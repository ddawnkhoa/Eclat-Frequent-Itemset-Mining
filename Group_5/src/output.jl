# Ghi kết quả frequent itemsets theo định dạng SPMF
function write_spmf_output(filepath::String, results)
    open(filepath, "w") do file
        for (itemset, support) in results
            items_string = join(itemset, " ")
            println(file, "$items_string #SUP: $support")
        end
    end
end
