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
    function JiveTestSet(args...; failfast::Union{Bool, Nothing} = nothing, kwargs...)
        if VERSION >= v"1.9.0-DEV.623" && isnothing(failfast)
            # pass failfast state into child testsets
            parent_ts = get_testset()
            if parent_ts isa JiveTestSet
                failfast = parent_ts.default.failfast
            else
                failfast = false
            end
        end
        new(UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), compat_default_testset(args...; failfast = failfast, kwargs...))
    end
end

using .Test: TESTSET_PRINT_ENABLE

function record_dont_show_backtrace end
# from julia/stdlib/Test/src/Test.jl  record(ts::DefaultTestSet, t::Union{Fail, Error}; print_result::Bool=TESTSET_PRINT_ENABLE[])
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
        ts.failfast && throw(FailFastError())
    end
    return t
end

# from julia/stdlib/Test/src/logging.jl  record(ts::DefaultTestSet, t::Test.LogTestFailure)
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
        ts.failfast && throw(FailFastError())
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

if VERSION >= v"1.12.0-DEV.1812" # julia commit 6136893eeed0c3559263a5aa465b630d2c7dc821
    import .Test: get_rng, set_rng!
end
using .Test: AbstractRNG
get_rng(ts::JiveTestSet) = get_rng(ts.default)
set_rng!(ts::JiveTestSet, rng::AbstractRNG) = set_rng!(ts.default, rng)

### @testset filter

using .Test: Random, _check_testset, default_rng
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

    if tests.head === :for
        return compat_testset_forloop(args, tests, __source__)
    elseif tests.head === :let
        return compat_testset_context(args, tests, __source__)
    else
        return compat_testset_beginend_call(args, tests, __source__)
    end
end

macro testset(ex::Expr, rest_args...)
    args = (ex, rest_args...)
    isempty(args) && error("No arguments to @testset")

    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests,Expr) || (tests.head !== :for && tests.head !== :block && tests.head !== :call && tests.head !== :let)

        error("Expected function call, begin/end block or for loop as argument to @testset")
    end

    if tests.head === :for
        return compat_testset_forloop(args, tests, __source__)
    elseif tests.head === :let
        return compat_testset_context(args, tests, __source__)
    else
        return compat_testset_beginend_call(args, tests, __source__)
    end
end

# module Jive
