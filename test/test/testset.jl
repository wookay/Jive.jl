# julia 1.6.0-DEV.1437 commit 68c71f577275a16fffb743b2058afdc2d635068f
module test_testset_verbose

using Test

@testset "Verbose 1" verbose = true begin
    @testset "Verbose 2" begin
        @test true
    end
end

end # module test_testset_verbose


# julia 1.9.0-DEV.623 commit 88def1afe16acdfe41b15dc956742359d837ce04
module test_testset_failfast

using Test

@testset failfast = true begin
    @test true
end

end # module test_testset_failfast


using Jive
@If VERSION >= v"1.8.0-DEV.809" module test_testset_42518

using Test

function foo()
    @test true
end

function bar(n)
    @test n > 1
end

@testset foo()
@testset bar(2)

end # module test_testset_42518


module test_testset_let

using Test

@testset let (fname, events) = ("fpath", [])
    @test fname == "fpath"
end

end # module test_testset_let


module test_testset_results

using Test

# from julia/stdlib/Test/test/nothrow_testset.jl
mutable struct NoThrowTestSet <: Test.AbstractTestSet
    results::Vector
    NoThrowTestSet(desc) = new([])
end
Test.record(ts::NoThrowTestSet, t::Test.Result) = (push!(ts.results, t); t)
Test.finish(ts::NoThrowTestSet) = ts.results

module M
    n = 42
end

let results = @testset NoThrowTestSet begin
    @test isconst(M, :zero) # Pass   :test
    @test isconst(M, :n)    # Fail   :test
    @test isconst(42)       # Error  :test_error
    @test 42                # Error  :test_nonbool
    @test_broken 1 == 2     # Broken :test
    @test_skip   1 == 2     # Broken :skipped
end

result = popfirst!(results)
@test result isa Test.Pass
@test result.test_type === :test
@test result.value === true

result = popfirst!(results)
@test result isa Test.Fail
@test result.test_type === :test
if VERSION >= v"1.6.0-DEV.1148"
    @test result.value == "false"
else
    @test result.value === false
end

result = popfirst!(results)
@test result isa Test.Error
@test result.test_type === :test_error
@test startswith(result.value, "MethodError(isconst, (42,), ")

result = popfirst!(results)
@test result isa Test.Error
@test result.test_type === :test_nonbool
@test result.value == "42"

result = popfirst!(results)
@test result isa Test.Broken
@test result.test_type === :test

result = popfirst!(results)
@test result isa Test.Broken
@test result.test_type === :skipped

end # let results = @testset NoThrowTestSet
end # module test_testset_results


@If VERSION >= v"1.9.0-DEV.1055" module test_testset_ContextTestSet

using Test

# from julia/stdlib/Test/test/runtests.jl  # julia commit 76d5b14c9c280c52b2c275e6cf449fe1ba7fc8d2
@testset "Context display in @testset let blocks" begin
    # Mock parent testset that just captures results
    struct MockParentTestSet <: Test.AbstractTestSet
        results::Vector{Any}
        MockParentTestSet() = new([])
    end
    Test.record(ts::MockParentTestSet, t) = (push!(ts.results, t); t)
    Test.finish(ts::MockParentTestSet) = ts

    @testset "context shown when a context testset fails" begin
        mock_parent1 = MockParentTestSet()
        ctx_ts1 = Test.ContextTestSet(mock_parent1, :x, 42)

        fail_result = Test.Fail(:test, "x == 99", "42 == 99", "42", nothing, LineNumberNode(1, :test), false)
        Test.record(ctx_ts1, fail_result)

        @test length(mock_parent1.results) == 1
        recorded_fail = mock_parent1.results[1]
        @test recorded_fail isa Test.Fail
        @test recorded_fail.context !== nothing
        @test occursin("x = 42", recorded_fail.context)
    end
end

end # module test_testset_ContextTestSet


@If VERSION >= v"1.6" module test_testset_rng

using Test, Random

rng = VERSION >= v"1.7.0-DEV.1224" ? Random.Xoshiro(0x2e026445595ed28e, 0x07bb81ac4c54926d, 0x83d7d70843e8bad6, 0xdbef927d150af80b, 0xdbf91ddf2534f850) : Random.MersenneTwister()

# @testset rng  v1.12.0-DEV.1812  julia commit 6136893eeed0c3559263a5aa465b630d2c7dc821
@testset rng=rng begin
    f = VERSION >= v"1.12.0-DEV.1812" ? (==) : (!=)
    @test f(rand(), 0.559472630416976)
end

end # module test_testset_rng
