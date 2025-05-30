using Pkg
Pkg.add("FiniteDiff")

using DifferentiationInterface, DifferentiationInterfaceTest
using DifferentiationInterface: DenseSparsityDetector
using FiniteDiff: FiniteDiff
using SparseMatrixColorings
using Test

using ExplicitImports
check_no_implicit_imports(DifferentiationInterface)

LOGGING = get(ENV, "CI", "false") == "false"

for backend in [AutoFiniteDiff()]
    @test check_available(backend)
    @test check_inplace(backend)
    @test DifferentiationInterface.inner_preparation_behavior(backend) isa
        DifferentiationInterface.PrepareInnerSimple
end

@testset "Dense" begin
    test_differentiation(
        AutoFiniteDiff(),
        default_scenarios(;
            include_constantified=true,
            include_cachified=true,
            include_constantorcachified=true,
            use_tuples=true,
            include_smaller=true,
        );
        excluded=[:second_derivative, :hvp],
        logging=LOGGING,
    )

    test_differentiation(
        SecondOrder(AutoFiniteDiff(; relstep=1e-5, absstep=1e-5), AutoFiniteDiff()),
        default_scenarios();
        logging=LOGGING,
        rtol=1e-2,
    )

    test_differentiation(
        [
            AutoFiniteDiff(; relstep=cbrt(eps(Float64))),
            AutoFiniteDiff(; relstep=cbrt(eps(Float64)), absstep=cbrt(eps(Float64))),
            AutoFiniteDiff(; dir=0.5),
        ];
        excluded=[:second_derivative, :hvp],
        logging=LOGGING,
    )
end

@testset "Sparse" begin
    test_differentiation(
        MyAutoSparse(AutoFiniteDiff()),
        sparse_scenarios();
        excluded=SECOND_ORDER,
        logging=LOGGING,
    )
end

@testset "Complex" begin
    test_differentiation(AutoFiniteDiff(), complex_scenarios(); logging=LOGGING)
    test_differentiation(
        AutoSparse(
            AutoFiniteDiff();
            sparsity_detector=DenseSparsityDetector(AutoFiniteDiff(); atol=1e-5),
            coloring_algorithm=GreedyColoringAlgorithm(),
        ),
        complex_sparse_scenarios();
        logging=LOGGING,
    )
end;
