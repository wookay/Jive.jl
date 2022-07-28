# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: AbstractTestSet, DefaultTestSet

function compat_default_testset(args...; kwargs...)::DefaultTestSet
    if VERSION < v"1.9.0-DEV.623"
        ignore_keys = Vector{Symbol}()
        push!(ignore_keys, :failfast)
        if VERSION < v"1.6.0-DEV.1437"
            push!(ignore_keys, :verbose)
        end
        filtered_kwargs = filter(kv -> !(first(kv) in ignore_keys), kwargs)
        DefaultTestSet(args...; filtered_kwargs...)
    else
        DefaultTestSet(args...; kwargs...)
    end
end

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
                Base.show_backtrace(stdout, scrub_backtrace(backtrace()))
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

# compat
testset_beginend_call = VERSION >= v"1.8.0-DEV.809" ? Test.testset_beginend_call : Test.testset_beginend
trigger_test_failure_break = VERSION >= v"1.9.0-DEV.228" ? Test.trigger_test_failure_break : (err) -> nothing
FailFastError = VERSION >= v"1.9.0-DEV.623" ? Test.FailFastError : ErrorException

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


### compat @testset let
if VERSION >= v"1.9.0-DEV.1061"
    testset_context = Test.testset_context
else
struct Fail <: Test.Result
    orig_expr::String
    data::Union{Nothing, String}
    value::String
    context::Union{Nothing, String}
    source::LineNumberNode
    message_only::Bool
    function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool)
        return new(test_type,
            string(orig_expr),
            data === nothing ? nothing : string(data),
            string(isa(data, Type) ? typeof(value) : value),
            context,
            source,
            message_only)
    end
end

"""
    ContextTestSet

Passes test failures through to the parent test set, while adding information
about a context object that is being tested.
"""
struct ContextTestSet <: AbstractTestSet
    parent_ts::AbstractTestSet
    context_name::Union{Symbol, Expr}
    context::Any
end

function ContextTestSet(name::Union{Symbol, Expr}, @nospecialize(context))
    if (name isa Expr) && (name.head != :tuple)
        error("Invalid syntax: $(name)")
    end
    return ContextTestSet(get_testset(), name, context)
end
record(c::ContextTestSet, t) = record(c.parent_ts, t)
function record(c::ContextTestSet, t::Fail)
    context = string(c.context_name, " = ", c.context)
    context = t.context === nothing ? context : string(t.context, "\n              ", context)
    record(c.parent_ts, Fail(t.test_type, t.orig_expr, t.data, t.value, context, t.source, t.message_only))
end

"""
Generate the code for an `@testset` with a `let` argument.
"""
function testset_context(args, tests, source)
    desc, testsettype, options = Test.parse_testset_args(args[1:end-1])
    if desc !== nothing || testsettype !== nothing
        # Reserve this syntax if we ever want to allow this, but for now,
        # just do the transparent context test set.
        error("@testset with a `let` argument cannot be customized")
    end

    assgn = tests.args[1]
    if !isa(assgn, Expr) || assgn.head !== :(=)
        error("`@testset let` must have exactly one assignment")
    end
    assignee = assgn.args[1]

    tests.args[2] = quote
        $push_testset($(ContextTestSet)($(QuoteNode(assignee)), $assignee; $options...))
        try
            $(tests.args[2])
        finally
            $pop_testset()
        end
    end

    return esc(tests)
end # function testset_context(args, tests, source)
end # if VERSION >= v"1.9.0-DEV.1061"

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
