module test_skip_testsets


module TestTools

export @testset

import Test: @testset
using Test: Test, AbstractTestSet, DefaultTestSet, Error, Random, testset_forloop, get_testset_depth, get_testset, push_testset, pop_testset, finish, record, _check_testset
if VERSION >= v"1.3.0-DEV.565"
    default_rng = Random.default_rng
else
    GLOBAL_RNG = Random.GLOBAL_RNG
end

skip_testsets = []

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl#L1065

macro testset(args...)
    isempty(args) && error("No arguments to @testset")

    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests,Expr) || (tests.head !== :for && tests.head !== :block)
        error("Expected begin/end block or for loop as argument to @testset")
    end

    if tests.head === :for
        ex = testset_forloop(args, tests, __source__)
    else
        if VERSION >= v"1.8.0-DEV.809"
            testset_beginend_call = Test.testset_beginend_call
        else
            testset_beginend_call = Test.testset_beginend
        end
        ex = testset_beginend_call(args, tests, __source__)
    end
    desc = first(args)
    !(desc in skip_testsets) && return ex
end

end # module TestTools


using Test
using .TestTools
push!(TestTools.skip_testsets, "testset2")

@testset "testset1" begin
@test true
end

@testset "testset2" begin
@test true
end

@testset "testset3" begin
@test true
end

end # module test_skip_testsets
