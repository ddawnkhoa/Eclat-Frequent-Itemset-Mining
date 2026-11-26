function read_itemsets(filepath)
    itemsets = Dict{Tuple, Int}()
    duplicates = 0

    open(filepath, "r") do file
        for (line_number, line) in enumerate(eachline(file))
            line = strip(line)

            # Bỏ qua header và dòng trống của SPMF
            if isempty(line) || startswith(line, "@")
                continue
            end

            parts = split(line, "#SUP:")
            if length(parts) != 2
                error("Sai định dạng tại $filepath, dòng $line_number: $line")
            end

            item_text = strip(parts[1])
            support_text = strip(parts[2])

            items = parse.(Int, split(item_text))
            support = parse(Int, support_text)

            # Chuẩn hóa itemset: sắp xếp item bên trong itemset
            key = Tuple(sort(items))

            if haskey(itemsets, key)
                duplicates += 1
            end

            itemsets[key] = support
        end
    end

    return itemsets, duplicates
end

function compare_itemsets(julia_file, spmf_file)
    julia_sets, julia_duplicates = read_itemsets(julia_file)
    spmf_sets, spmf_duplicates = read_itemsets(spmf_file)

    julia_keys = Set(keys(julia_sets))
    spmf_keys = Set(keys(spmf_sets))

    missing_in_julia = setdiff(spmf_keys, julia_keys)
    extra_in_julia = setdiff(julia_keys, spmf_keys)

    support_mismatches = Tuple[]

    for key in intersect(julia_keys, spmf_keys)
        if julia_sets[key] != spmf_sets[key]
            push!(support_mismatches,
                  (key, julia_sets[key], spmf_sets[key]))
        end
    end

    matched = length(intersect(julia_keys, spmf_keys)) -
              length(support_mismatches)

    total_spmf = length(spmf_sets)
    match_rate = total_spmf == 0 ? 1.0 : matched / total_spmf

    exact_match =
        isempty(missing_in_julia) &&
        isempty(extra_in_julia) &&
        isempty(support_mismatches) &&
        julia_duplicates == 0 &&
        spmf_duplicates == 0 &&
        length(julia_sets) == length(spmf_sets)

    println("Julia itemsets: ", length(julia_sets))
    println("SPMF itemsets:  ", length(spmf_sets))
    println("Matched itemsets with same support: ", matched)
    println("Match rate: ", round(match_rate * 100, digits=4), "%")
    println("Exact match: ", exact_match ? "PASS" : "FAIL")

    println("\nItemsets missing in Julia: ", length(missing_in_julia))
    for key in collect(missing_in_julia)[1:min(10, length(missing_in_julia))]
        println("  ", key, " #SUP: ", spmf_sets[key])
    end

    println("\nExtra itemsets in Julia: ", length(extra_in_julia))
    for key in collect(extra_in_julia)[1:min(10, length(extra_in_julia))]
        println("  ", key, " #SUP: ", julia_sets[key])
    end

    println("\nSupport mismatches: ", length(support_mismatches))
    for (key, julia_support, spmf_support) in
        support_mismatches[1:min(10, length(support_mismatches))]
        println("  ", key,
                " Julia=", julia_support,
                " SPMF=", spmf_support)
    end

    println("\nDuplicate itemsets:")
    println("  Julia: ", julia_duplicates)
    println("  SPMF:  ", spmf_duplicates)

    return exact_match
end

if length(ARGS) != 2
    println("Usage: julia tests/compare_spmf.jl <julia_output> <spmf_output>")
else
    compare_itemsets(ARGS[1], ARGS[2])
end
