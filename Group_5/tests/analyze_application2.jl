
# Analyze frequent itemsets and biological protein patterns.
# Run: julia tests/analyze_application2.jl

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
const DATA_DIR = joinpath(PROJECT_ROOT, "data", "application2")
const RESULT_DIR = joinpath(PROJECT_ROOT, "results", "application2")

const MINSUP_VALUES = [20, 25, 30, 35, 40]

# ============================================================
# PART 1: COMMON DATA LOADING
# ============================================================

function parse_csv_line(line::String)
    fields = String[]
    buffer = IOBuffer()
    in_quotes = false
    chars = collect(line)
    i = 1

    while i <= length(chars)
        c = chars[i]

        if c == '"'
            if in_quotes && i < length(chars) && chars[i + 1] == '"'
                print(buffer, '"')
                i += 1
            else
                in_quotes = !in_quotes
            end
        elseif c == ',' && !in_quotes
            push!(fields, String(take!(buffer)))
        else
            print(buffer, c)
        end

        i += 1
    end

    push!(fields, String(take!(buffer)))
    return fields
end

function csv_escape(value)
    s = string(value)
    return "\"" * replace(s, "\"" => "\"\"") * "\""
end

# Load ItemID -> Kmer.
function load_kmer_mapping(filepath)
    mapping = Dict{Int, String}()

    open(filepath, "r") do file
        readline(file)

        for line in eachline(file)
            isempty(strip(line)) && continue
            fields = parse_csv_line(line)

            mapping[parse(Int, fields[1])] = fields[2]
        end
    end

    return mapping
end

# Load TransactionID -> Accession.
function load_protein_metadata(filepath)
    metadata = Dict{Int, String}()

    open(filepath, "r") do file
        readline(file)

        for line in eachline(file)
            isempty(strip(line)) && continue
            fields = parse_csv_line(line)

            transaction_id = parse(Int, fields[1])
            accession = fields[2]

            metadata[transaction_id] = accession
        end
    end

    return metadata
end

# Load each transaction as a set of item IDs.
function load_transactions(filepath)
    transactions = Vector{Set{Int}}()

    open(filepath, "r") do file
        for line in eachline(file)
            isempty(strip(line)) && continue

            items = Set{Int}()

            for token in split(strip(line))
                push!(items, parse(Int, token))
            end

            push!(transactions, items)
        end
    end

    return transactions
end

# ============================================================
# PART 2: FREQUENT ITEMSET STATISTICS
# ============================================================

function analyze_statistics(filepath, minsup)
    if !isfile(filepath)
        println("Missing result file: $filepath")
        return
    end

    length_counts = Dict{Int, Int}()
    support_counts = Dict{Int, Int}()
    top_itemsets = Tuple{String, Int, Int}[]

    total = 0

    open(filepath, "r") do file
        for line in eachline(file)
            isempty(strip(line)) && continue

            parts = split(line, "#SUP:")
            length(parts) == 2 || continue

            itemset = strip(parts[1])
            support = parse(Int, strip(parts[2]))
            item_count = length(split(itemset))

            total += 1

            length_counts[item_count] =
                get(length_counts, item_count, 0) + 1

            support_counts[support] =
                get(support_counts, support, 0) + 1

            push!(top_itemsets, (itemset, support, item_count))
        end
    end

    println("\n====================================")
    println("MINIMUM SUPPORT: $minsup%")
    println("====================================")
    println("Total frequent itemsets: $total")

    println("\nItemsets by length:")
    for (len, count) in sort(collect(length_counts), by = first)
        println("Length $len: $count")
    end

    println("\nItemsets by support:")
    for (support, count) in sort(collect(support_counts), by = first)
        println("Support $support: $count")
    end

    sort!(top_itemsets, by = x -> (-x[2], x[1]))

    println("\nTop 10 itemsets by support:")
    for (itemset, support, len) in Iterators.take(top_itemsets, 10)
        println("$itemset | Support: $support | Length: $len")
    end
end

# ============================================================
# PART 3: BIOLOGICAL INTERPRETATION
# ============================================================

function analyze_biology(
    minsup,
    mapping,
    metadata,
    transactions
)
    input_file = joinpath(
        DATA_DIR,
        "frequent_itemsets_minsup$(minsup).txt"
    )

    output_file = joinpath(
        RESULT_DIR,
        "biological_itemsets_minsup$(minsup).csv"
    )

    if !isfile(input_file)
        println("Missing result file: $input_file")
        return
    end

    total = 0
    support_mismatches = 0

    open(input_file, "r") do input
        open(output_file, "w") do output

            println(output,
                "ItemsetIDs,KmerCombination,Support," *
                "SupportPercent,ItemsetLength," *
                "TransactionIDs,ProteinAccessions"
            )

            for line in eachline(input)
                isempty(strip(line)) && continue

                parts = split(line, "#SUP:")
                length(parts) == 2 || continue

                item_ids = parse.(
                    Int,
                    split(strip(parts[1]))
                )

                reported_support = parse(
                    Int,
                    strip(parts[2])
                )

                # Find transactions containing all items.
                matching_ids = Int[]

                for (transaction_id, transaction) in enumerate(transactions)
                    if all(item -> item in transaction, item_ids)
                        push!(matching_ids, transaction_id)
                    end
                end

                actual_support = length(matching_ids)

                if actual_support != reported_support
                    support_mismatches += 1
                end

                # Convert Item IDs into k-mers.
                kmers = [
                    get(mapping, id, "UNKNOWN_$id")
                    for id in item_ids
                ]

                # Convert Transaction IDs into accessions.
                accessions = [
                    get(metadata, id, "UNKNOWN_$id")
                    for id in matching_ids
                ]

                support_percent =
                    actual_support / length(transactions) * 100

                values = [
                    join(item_ids, " "),
                    join(kmers, " + "),
                    reported_support,
                    round(support_percent, digits = 2),
                    length(item_ids),
                    join(matching_ids, ";"),
                    join(accessions, ";")
                ]

                println(output, join(csv_escape.(values), ","))

                total += 1
            end
        end
    end

    println("\nBiological analysis - MinSup = $minsup%")
    println("Itemsets exported: $total")
    println("Support mismatches: $support_mismatches")
    println("Output: $output_file")
end

# ============================================================
# PART 4: MAIN
# ============================================================

function main()
    transaction_file = joinpath(
        DATA_DIR, "protein_transactions.txt"
    )

    mapping_file = joinpath(
        DATA_DIR, "kmer_mapping.csv"
    )

    metadata_file = joinpath(
        DATA_DIR, "protein_metadata.csv"
    )

    # Check input files.
    for filepath in [
        transaction_file,
        mapping_file,
        metadata_file
    ]
        if !isfile(filepath)
            error("Missing input file: $filepath")
        end
    end

    # Create output directory.
    mkpath(RESULT_DIR)

    # Load input data.
    mapping = load_kmer_mapping(mapping_file)
    metadata = load_protein_metadata(metadata_file)
    transactions = load_transactions(transaction_file)

    if length(transactions) != length(metadata)
        error("Transaction count and metadata count do not match.")
    end

    println("=== APPLICATION 2: PROTEIN ANALYSIS ===")
    println("Transactions: ", length(transactions))
    println("K-mer mappings: ", length(mapping))
    println("Protein metadata: ", length(metadata))
    println("MinSup values: ", MINSUP_VALUES)

    for minsup in MINSUP_VALUES
        result_file = joinpath(
            DATA_DIR,
            "frequent_itemsets_minsup$(minsup).txt"
        )

        println("\n\n========== MinSup $minsup% ==========")

        # 1. Frequent itemset statistics.
        analyze_statistics(result_file, minsup)

        # 2. Biological interpretation and CSV export.
        analyze_biology(
            minsup,
            mapping,
            metadata,
            transactions
        )
    end

    println("\n=== APPLICATION 2 ANALYSIS COMPLETED ===")
    println("CSV output directory: ", RESULT_DIR)
end

main()
