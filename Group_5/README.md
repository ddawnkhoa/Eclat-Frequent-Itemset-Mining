# Eclat Frequent Itemset Mining

An implementation of the **Eclat (Equivalence Class Transformation)** algorithm for Frequent Itemset Mining (FIM), developed using Julia.

This project includes two implementations:
- **Vector-based Eclat:** Uses transaction ID sets (tidsets) represented by vectors.
- **BitVector-based Eclat:** Uses bit vectors and bitwise operations to perform efficient tidset intersections.

The project also evaluates the correctness, execution time, memory usage, and scalability of both implementations, with SPMF used as a reference implementation.

## 1. Project Structure

```text
C:.
├───data
│   ├───application2
│   ├───benchmark
│   │   └───transaction_length
│   └───toy
│       └───outputs
├───docs
│   └───figures
├───notebooks
├───results
│   ├───application1
│   ├───application2
│   ├───correctness
│   ├───frequent_itemset_count
│   ├───memory
│   ├───optimization
│   ├───runtime
│   ├───scalability
│   └───transaction_length
├───src
│   └───algorithm
└───tests
```

## 2. Requirements

- Julia (version 1.13.4 or compatible with the project dependencies).
- Git.
- Visual Studio Code or another Julia-compatible editor (optional).

## 3. Installation

### Step 1: Clone the repository

```bash
git clone https://github.com/ddawnkhoa/Eclat-Frequent-Itemset-Mining.git
cd Group_5
```

### Step 2: Install project dependencies

Open a terminal in the project root directory and run:

```bash
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

This command installs the dependencies specified in `Project.toml` and `Manifest.toml`.

## 4. Running the Project

Run commands from the project root directory.

### 4.1. Run the main program

```bash
julia --project=. src/main.jl
```

### 4.2. Run Application 1: Retail Market Basket Analysis

```bash
julia --project=. tests/run_application1.jl
```

This application performs frequent itemset mining on retail transaction data and generates association rules.

Generated results:
- `results/application1/frequent_itemsets.csv`
- `results/application1/association_rules.csv`

### 4.3. Run Application 2: Protein Sequence Mining

```bash
julia --project=. tests/run_application2.jl
```

This application converts protein sequences into transactions of distinct overlapping 3-mers and performs frequent itemset mining.

Generated results include frequent itemsets at different minimum support thresholds under:

```text
results/application2/
```

### 4.4. Run Unit Tests

Execute the complete unit test suite:

```bash
julia --project=. tests/runtests.jl
```

The test suite covers:
- Algorithm correctness.
- Vector and BitVector implementations.
- Optimization correctness.
- Association rule generation.
- Input and output processing.
- SPMF-related tests.

A successful execution should report zero failed and zero errored tests.

Latest runtests.jl output:
========== ECLAT UNIT TESTS ==========


Running test_correctness.jl ...

Running test_bitvector.jl ...

Testing: normal.txt
Vector itemsets: 7
BitVector itemsets: 7
Result: PASS

Testing: empty.txt
Vector itemsets: 0
BitVector itemsets: 0
Result: PASS

Testing: singleton_only.txt
Vector itemsets: 1
BitVector itemsets: 1
Result: PASS

Testing: no_frequent.txt
Vector itemsets: 0
BitVector itemsets: 0
Result: PASS

Testing: multi_itemset.txt
Vector itemsets: 14
BitVector itemsets: 14
Result: PASS

Running test_optimization.jl ...

Dataset: normal.txt
Correctness: PASS
Frequent itemsets: 7
Vector runtime: 0.000018 s
BitVector runtime: 0.000019 s
Speedup: 0.931x
Vector allocated: 0.0036 MB
BitVector allocated: 0.0037 MB
Memory ratio: 0.983x

Dataset: empty.txt
Correctness: PASS
Frequent itemsets: 0
Vector runtime: 0.000001 s
BitVector runtime: 0.000002 s
Speedup: 0.829x
Vector allocated: 0.0001 MB
BitVector allocated: 0.0001 MB
Memory ratio: 1.000x

Dataset: singleton_only.txt
Correctness: PASS
Frequent itemsets: 1
Vector runtime: 0.000012 s
BitVector runtime: 0.000012 s
Speedup: 0.947x
Vector allocated: 0.0007 MB
BitVector allocated: 0.0007 MB
Memory ratio: 1.000x

Dataset: no_frequent.txt
Correctness: PASS
Frequent itemsets: 0
Vector runtime: 0.000002 s
BitVector runtime: 0.000002 s
Speedup: 0.949x
Vector allocated: 0.0001 MB
BitVector allocated: 0.0001 MB
Memory ratio: 1.000x

Dataset: multi_itemset.txt
Correctness: PASS
Frequent itemsets: 15
Vector runtime: 0.000025 s
BitVector runtime: 0.000024 s
Speedup: 1.042x
Vector allocated: 0.0088 MB
BitVector allocated: 0.0084 MB
Memory ratio: 1.045x

Saved benchmark results: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\results\optimization\vector_bitvector_optimization.csv

Running test_association_rules.jl ...
Frequent itemsets: 7
Association rules: 12
Test completed successfully.

Running test_io.jl ...

Running test_spmf.jl ...

================================
Dataset: normal.txt
Minimum support: 2
================================
Transactions: 5
Frequent itemsets: 7
Output: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\data\toy\outputs\normal_julia.txt
Status: PASS

================================
Dataset: empty.txt
Minimum support: 1
================================
Transactions: 0
Frequent itemsets: 0
Output: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\data\toy\outputs\empty_julia.txt
Status: PASS

================================
Dataset: singleton_only.txt
Minimum support: 3
================================
Transactions: 4
Frequent itemsets: 1
Output: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\data\toy\outputs\singleton_only_julia.txt
Status: PASS

================================
Dataset: no_frequent.txt
Minimum support: 3
================================
Transactions: 3
Frequent itemsets: 0
Output: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\data\toy\outputs\no_frequent_julia.txt
Status: PASS

================================
Dataset: multi_itemset.txt
Minimum support: 2
================================
Transactions: 6
Frequent itemsets: 15
Output: C:\Users\user\Documents\repos\Eclat-Frequent-Itemset-Mining\Group_5\data\toy\outputs\multi_itemset_julia.txt
Status: PASS
Test Summary:                 | Pass  Total  Time
Eclat Frequent Itemset Mining |   47     47  8.4s

========== UNIT TESTS COMPLETED ==========

## 5. Benchmarking

The project provides scripts for evaluating algorithm performance.

Run the following commands from the project root:

**Runtime benchmark (Modify dataset and minsup value first in benchmark_runtime.jl)**
```bash
julia --project=. tests/benchmark_runtime.jl
```

**Memory benchmark(Modify dataset and minsup value first in benchmark_memory.jl)**`
```bash
julia --project=. tests/benchmark_memory.jl
```

**Scalability benchmark**`
```bash
julia --project=. tests/benchmark_scalability.jl
```

**Transaction length benchmark**
```bash
julia --project=. tests/benchmark_transaction_length.jl
```

Additional scripts are available for dataset statistics, correctness comparison, and transaction length dataset generation.

Benchmark results are saved in the corresponding subdirectories under `results/`.

## 6. Google Colab Demo

A Google Colab notebook is provided to demonstrate the project without requiring a local Julia development environment.

**Open the demo notebook:**

[Google Colab Demo](https://colab.research.google.com/drive/1UMUlnUJp-LPoc306_W_TvIl4vNRrmAsh?usp=sharing)

## 7. Authors

| Name | Student ID |
|---|---|
| Ly Dang Khoa | 24127060 |
| Ho Gia Phuc | 24127217 |

**Class:** 24KHMT1

**Course:** Data Mining and Applications

**Institution:** University of Science, Vietnam National University, Ho Chi Minh City