using Test

project_root = dirname(@__DIR__)
include(joinpath(project_root, "src", "structures_bitvector.jl"))
include(joinpath(project_root, "src", "algorithm", "eclat_bitvector.jl"))
include(joinpath(project_root, "src", "association_rules.jl"))

@testset "Association Rules Test" begin

    # Test data:
    transactions = [
        [1, 2, 3],
        [1, 2],
        [1, 3],
        [2, 3],
        [1, 2, 3]
    ]

    ntransactions = length(transactions)
    minsup = 2
    minconf = 0.50

    # Chạy Eclat BitVector của nhóm
    db = build_vertical_bit_db(transactions)
    frequent_itemsets = eclat_bitvector(db, minsup)

    # Chuyển sang dictionary support
    supports = build_support_dict(frequent_itemsets)

    # Kiểm tra support count
    @test supports[(1,)] == 4
    @test supports[(2,)] == 4
    @test supports[(3,)] == 4

    @test supports[(1, 2)] == 3
    @test supports[(1, 3)] == 3
    @test supports[(2, 3)] == 3

    @test supports[(1, 2, 3)] == 2

    # Sinh luật
    rules = generate_association_rules(
        supports,
        ntransactions;
        minconf = minconf
    )

    # Có 12 luật đạt MinConf 50%
    @test length(rules) == 12

    # Kiểm tra một luật cụ thể: {1} => {2}
    rule = only(filter(
        r -> r.antecedent == (1,) &&
             r.consequent == (2,),
        rules
    ))

    @test rule.support ≈ 0.60
    @test rule.confidence ≈ 0.75
    @test rule.lift ≈ 0.9375

    # Kiểm tra thứ tự Lift giảm dần
    lifts = [r.lift for r in rules]
    @test issorted(lifts, rev=true)

    println("Frequent itemsets: ", length(frequent_itemsets))
    println("Association rules: ", length(rules))
    println("Test completed successfully.")

end
