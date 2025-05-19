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

using .Test: TESTSET_PRINT_ENABLE, Fail, Error

# from julia/stdlib/Test/src/Test.jl
function record_dont_show_backtrace(ts::DefaultTestSet, t::Union{Fail, Error}; print_result::Bool=TESTSET_PRINT_ENABLE[])
    if print_result
        print(ts.description, ": ")
        # don't print for interrupted tests
        if !(t isa Error) || t.test_type !== :test_interrupted
            print(t)
            if !isa(t, Error) # if not gets printed in the show method
            #    Base.show_backtrace(stdout, scrub_backtrace(backtrace(), ts.file, extract_file(t.source)))
            end
            println()
        end
    end
    push!(ts.results, t)
    if VERSION >= v"1.9.0-DEV.623"
        (FAIL_FAST[] || ts.failfast) && throw(FailFastError())
    else
        FAIL_FAST[] && throw(FailFastError())
    end
    return t
end

# from julia/stdlib/Test/src/logging.jl
function record_dont_show_backtrace(ts::DefaultTestSet, t::Test.LogTestFailure)
    if TESTSET_PRINT_ENABLE[]
        printstyled(ts.description, ": ", color=:white)
        print(t)
        # Base.show_backtrace(stdout, scrub_backtrace(backtrace(), ts.file, extract_file(t.source)))
        println()
    end
    # Hack: convert to `Fail` so that test summarization works correctly
    push!(ts.results, Fail(:test, t.orig_expr, t.logs, nothing, nothing, t.source, false))
    if VERSION >= v"1.9.0-DEV.623"
        (FAIL_FAST[] || ts.failfast) && throw(FailFastError())
    else
        FAIL_FAST[] && throw(FailFastError())
    end
    return t
end

import .Test: record, finish

function record(ts::JiveTestSet, t::Union{Fail, Error, Test.LogTestFailure})
    return record_dont_show_backtrace(ts.default, t)
end

function record(ts::JiveTestSet, t::Union{Test.Pass, Test.Broken, AbstractTestSet})
    return record(ts.default, t)
end

function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end


### @testset filter

using .Test: Random, testset_forloop, _check_testset, default_rng
VERSION >= v"1.12.0-DEV.1812" && isdefined(Test, :get_rng) && using .Test: get_rng, set_rng!
import .Test: @testset

macro testset(name::String, rest_args...)
    global jive_testset_filter
    if jive_testset_filter !== nothing
        !jive_testset_filter(name) && return nothing
    end

    args = (name, rest_args...)
    isempty(args) && error("No arguments to @testset")

    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests,Expr) || (tests.head !== :for && tests.head !== :block && tests.head !== :call && tests.head !== :let)

        error("Expected function call, begin/end block or for loop as argument to @testset")
    end

    # set by runtests(; failfast::Bool)
    # FAIL_FAST[] = Base.get_bool_env("JULIA_TEST_FAILFAST", false)

    if tests.head === :for
        return testset_forloop(args, tests, __source__)
    elseif tests.head === :let
        return testset_context(args, tests, __source__)
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
