
# tests/preprocess_application2.jl
# Chuyen FASTA protein thanh transaction k-mer cho Eclat.
# Moi protein = 1 transaction.
# Moi item = 1 k-mer duy nhat trong protein.

using Printf

# 1. Xac dinh project root va thu muc du lieu

projectRoot = dirname(@__DIR__)

dataDir = joinpath(projectRoot, "data", "application2")

# Tu dong tim file FASTA trong application2
fastaFiles = filter(
    f -> endswith(lowercase(f), ".fasta") ||
         endswith(lowercase(f), ".fa"),
    readdir(dataDir)
)

if isempty(fastaFiles)
    error("Khong tim thay file .fasta hoac .fa trong: $dataDir")
elseif length(fastaFiles) > 1
    error("Tim thay nhieu file FASTA. Hay chi de lai file dataset can xu ly.")
end

fastaPath = joinpath(dataDir, only(fastaFiles))

transactionPath = joinpath(dataDir, "protein_transactions.txt")
mappingPath = joinpath(dataDir, "kmer_mapping.csv")
metadataPath = joinpath(dataDir, "protein_metadata.csv")


# 2. Cau hinh k-mer
k = 3

# 20 amino acid chuan
validAminoAcids = Set("ACDEFGHIKLMNPQRSTVWY")

# 3. Doc FASTA

headers = String[]
sequences = String[]

currentHeader = ""
currentSequence = IOBuffer()

open(fastaPath, "r") do file
    global currentHeader, currentSequence
    for line in eachline(file)
        line = strip(line)

        if isempty(line)
            continue
        end

        if startswith(line, ">")
            # Luu entry truoc do
            if !isempty(currentHeader)
                push!(headers, currentHeader)
                push!(sequences, String(take!(currentSequence)))
            end

            currentHeader = line[2:end]
            currentSequence = IOBuffer()
        else
            write(currentSequence, uppercase(line))
        end
    end

    # Luu entry cuoi cung
    if !isempty(currentHeader)
        push!(headers, currentHeader)
        push!(sequences, String(take!(currentSequence)))
    end
end

if isempty(sequences)
    error("File FASTA khong co protein sequence.")
end

println("FASTA: ", fastaPath)
println("So protein doc duoc: ", length(sequences))

# 4. Tao tap k-mer cho moi protein

proteinKmers = Vector{Set{String}}()

for sequence in sequences
    kmers = Set{String}()

    if length(sequence) >= k
        for i in 1:(length(sequence) - k + 1)
            kmer = sequence[i:(i + k - 1)]

            # Bo qua k-mer co amino acid khong chuan
            if all(aa -> aa in validAminoAcids, kmer)
                push!(kmers, kmer)
            end
        end
    end

    push!(proteinKmers, kmers)
end

# --------------------------------------------------
# 5. Tao mapping k-mer -> item ID
# --------------------------------------------------

allKmers = sort(collect(union(proteinKmers...)))

kmerToId = Dict{String, Int}()

for (id, kmer) in enumerate(allKmers)
    kmerToId[kmer] = id
end

# 6. Ghi transaction

open(transactionPath, "w") do file
    for kmers in proteinKmers
        itemIds = sort([kmerToId[kmer] for kmer in kmers])
        println(file, join(itemIds, " "))
    end
end

# 7. Ghi k-mer mapping CSV

function csvEscape(value)
    s = string(value)
    s = replace(s, "\"" => "\"\"")
    return "\"" * s * "\""
end

open(mappingPath, "w") do file
    println(file, "ItemID,Kmer")

    for kmer in allKmers
        println(file, kmerToId[kmer], ",", csvEscape(kmer))
    end
end


# 8. Ghi metadata protein CSV

function getAccession(header)
    matchResult = match(r"^[^|]+\|([^|]+)\|", header)

    if matchResult !== nothing
        return matchResult.captures[1]
    end

    return first(split(header))
end

function getOrganism(header)
    matchResult = match(r"OS=(.+?)(?:\s+OX=|\s+GN=|\s+PE=|\s+SV=|$)", header)

    if matchResult !== nothing
        return matchResult.captures[1]
    end

    return "Unknown"
end

open(metadataPath, "w") do file
    println(file, "TransactionID,Accession,Organism,SequenceLength,UniqueKmerCount")

    for i in eachindex(sequences)
        accession = getAccession(headers[i])
        organism = getOrganism(headers[i])

        println(
            file,
            i, ",",
            csvEscape(accession), ",",
            csvEscape(organism), ",",
            length(sequences[i]), ",",
            length(proteinKmers[i])
        )
    end
end

# 9. Bao cao

println()
println("=== PREPROCESSING COMPLETED ===")
println("Transactions: ", length(sequences))
println("K-mer length: ", k)
println("Unique k-mers: ", length(allKmers))
println("Transaction file: ", transactionPath)
println("Mapping file: ", mappingPath)
println("Metadata file: ", metadataPath)
