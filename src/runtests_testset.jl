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

using .Test: TESTSET_PRINT_ENABLE, scrub_backtrace
import .Test: record, finish

# import .Test: record
function record(ts::JiveTestSet, t::Test.Pass)
    ts.default.n_passed += 1
    t
end

function record(ts::JiveTestSet, t::Test.Broken)
    push!(ts.default.results, t)
    t
end

function record(ts::JiveTestSet, t::Union{Test.Fail, Test.Error})
    if TESTSET_PRINT_ENABLE[]
        print(ts.default.description, ": ")
        # don't print for interrupted tests
        if !(t isa Test.Error) || t.test_type !== :test_interrupted
            print(t)
            if !isa(t, Test.Error) # if not gets printed in the show method
                Base.show_backtrace(stdout, compat_scrub_backtrace(backtrace(), ts.default, compat_extract_file(t.source)))
            end
            println()
        end
    end
    push!(ts.default.results, t)
    return t
end

function record(ts::JiveTestSet, t::AbstractTestSet)
    push!(ts.default.results, t)
end

# import .Test: finish
function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end


### @testset filter

using .Test: Random, Error, testset_forloop, _check_testset, default_rng
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
