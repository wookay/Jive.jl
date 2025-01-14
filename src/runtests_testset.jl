# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: AbstractTestSet, DefaultTestSet

mutable struct JiveTestSet <: AbstractTestSet
    compile_time_start::UInt64
    recompile_time_start::UInt64
    elapsed_time_start::UInt64
    compile_time::UInt64
    recompile_time::UInt64
    elapsed_time::UInt64
    default::DefaultTestSet
    function JiveTestSet(args...; kwargs...)
        new(UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), compat_default_testset(args...; kwargs...))
    end
end

import .Test: record, finish
function record(ts::JiveTestSet, t::Union{Test.Pass, Test.Broken, Test.Fail, Test.Error, Test.LogTestFailure, AbstractTestSet})
    record(ts.default, t)
end

function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end


### @testset filter

using .Test: Random, Error, testset_forloop, _check_testset, default_rng
VERSION >= v"1.12.0-DEV.1812" && isdefined(Test, :get_rng) && using .Test: get_rng, set_rng!
import .Test: @testset

macro testset(name::String, rest_args...)
    global jive_testset_filter
    if jive_testset_filter !== nothing
        !jive_testset_filter(name) && return nothing
    end

    args = (name, rest_args...)
    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests, Expr) || (tests.head !== :for && tests.head !== :block && tests.head !== :call && tests.head !== :let)
        error("Expected function call, begin/end block or for loop as argument to @testset")
    end

    if VERSION >= v"1.9.0-DEV.623"
        Test.FAIL_FAST[] = something(tryparse(Bool, get(ENV, "JULIA_TEST_FAILFAST", "false")), false)
    end

    if tests.head === :for
        return testset_forloop(args, tests, __source__)
    elseif tests.head === :let
        return Test.testset_context(args, tests, __source__)
    else
        return testset_beginend_call(args, tests, __source__)
    end
end

macro testset(tests::Expr)
    args = (tests,)
    if tests.head === :for
        return testset_forloop(args, tests, __source__)
    elseif tests.head === :let
        return testset_context(args, tests, __source__)
    else
        return testset_beginend_call(args, tests, __source__)
    end
end

# module Jive
