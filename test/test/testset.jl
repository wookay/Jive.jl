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
@test result.value == true

result = popfirst!(results)
@test result isa Test.Fail
@test result.test_type === :test
@test result.value == "false"

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
