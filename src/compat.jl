# module Jive

using .Test: AbstractTestSet, DefaultTestSet,
             get_testset, get_testset_depth, _check_testset,
             record, finish, print_test_results,
             parse_testset_args, # 0.7.0-DEV.1995
             Pass, Error, Broken,
             Random, default_rng

# override this function if you want to
# Jive.jive_print_testset_verbose(action::Symbol, ts::Test.AbstractTestSet)
function jive_print_testset_verbose(action::Symbol, ts)
end


# code from julia/stdlib/Test/src/Test.jl

# cumulative_compile_timing, cumulative_compile_time_ns
cumulative_compile_timing, cumulative_compile_time_ns = begin
    # julia commit 7074f04228d6149c2cefaa16064f30739f31da13
    if isdefined(Base, :cumulative_compile_timing)
        (Base.cumulative_compile_timing, Base.cumulative_compile_time_ns)
    else
        if VERSION >= v"1.6.0-DEV.1819" && isdefined(Base, :cumulative_compile_time_ns_before)
            ref_compile_timing = Ref{Bool}()
            function compile_timing(b::Bool)
                ref_compile_timing[] = b
            end
            function compile_time_ns()
                compile_time = ref_compile_timing[] ? Base.cumulative_compile_time_ns_before() : Base.cumulative_compile_time_ns_after()
                (compile_time, UInt64(0))
            end
            (compile_timing, compile_time_ns)
        elseif VERSION >= v"1.6.0-DEV.1088" && isdefined(Base, :cumulative_compile_time_ns)
            ((::Bool) -> nothing, () -> (Base.cumulative_compile_time_ns(), UInt64(0)))
        else
            ((::Bool) -> nothing, () -> (UInt64(0), UInt64(0)))
        end
    end
end

if VERSION >= v"1.9.0-DEV.228"
    using .Test: trigger_test_failure_break
else
    trigger_test_failure_break(@nospecialize(err)) = ccall(:jl_test_failure_breakpoint, Cvoid, (Any,), err)
end

if VERSION >= v"1.9.0-DEV.623"
    using .Test: FailFastError
else
    struct FailFastError <: Exception end
end

# compat Test.Fail
#
# v"1.11.0-DEV.336" # 4ac6b053473c4a588984b313ee0ee12dc7503e41
# backtrace::Union{Nothing, String}
# function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool, backtrace=nothing)
#
# v"1.10.0-DEV.579" # e8b9b5b7432a5215a78e9819c56433718fb7db22
# Test.Fail <: Test.Result
#
# v"1.9.0-DEV.1055" # ff1b563e3c6f3ee419de0f792c5ff42744448f1c
# context::Union{Nothing, String}
# -    function Fail(test_type::Symbol, orig_expr, data, value, source::LineNumberNode, message_only::Bool=false)
# +    function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool)
#
# v"1.8.0-DEV.363" # a03392ad4f3c01abdc5223283028af3523b6b356
# +    message_only::Bool
#
# v"1.6.0-DEV.1148" # 7d3dac44dc917a215607bfa1a6054a21846f02a7
# +struct Fail <: Result
# -    orig_expr
# -    data
# -    value
# +    orig_expr::String
# +    data::Union{Nothing, String}
# +    value::String
if VERSION >= v"1.9.0-DEV.1055" # julia commit ff1b563e3c
    using .Test: Fail
else
    import .Test: Fail
    function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool, backtrace=nothing)
        Fail(test_type, orig_expr, data, value, source)
    end
end

if VERSION >= v"1.10.0-DEV.1171" # julia commit 5304baa45a
using .Test: scrub_backtrace
else
import .Test: scrub_backtrace
function scrub_backtrace(bt, file_ts, file_t)
    scrub_backtrace(bt)
end
end # if VERSION >= v"1.10.0-DEV.1171"


# TestCounts, get_test_counts
if VERSION >= v"1.11.0-DEV.1529" # julia commit 9523361974
    using .Test: TestCounts, get_test_counts
else
struct TestCounts
    customized::Bool
    passes::Int
    fails::Int
    errors::Int
    broken::Int
    cumulative_passes::Int
    cumulative_fails::Int
    cumulative_errors::Int
    cumulative_broken::Int
    duration::String
end # if
format_duration(::AbstractTestSet) = "?s"
get_test_counts(ts::AbstractTestSet) = TestCounts(false, 0,0,0,0,0,0,0,0, format_duration(ts))
function get_test_counts(ts::DefaultTestSet)
    passes, fails, errors, broken = ts.n_passed, 0, 0, 0
    # cumulative results
    c_passes, c_fails, c_errors, c_broken = 0, 0, 0, 0
    #= @lock ts.results_lock =# for t in ts.results
        isa(t, Fail)   && (fails  += 1)
        isa(t, Error)  && (errors += 1)
        isa(t, Broken) && (broken += 1)
        if isa(t, AbstractTestSet)
            tc = get_test_counts(t)::TestCounts
            c_passes += tc.passes + tc.cumulative_passes
            c_fails  += tc.fails + tc.cumulative_fails
            c_errors += tc.errors + tc.cumulative_errors
            c_broken += tc.broken + tc.cumulative_broken
        end
    end
    duration = format_duration(ts)
    tc = TestCounts(true, passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken, duration)
    if VERSION >= v"1.13.0-DEV.1037" # julia commit 364ecb3a11
    #= @atomic :monotonic =# ts.anynonpass = (anynonpass(tc) ? 0x02 : 0x01)
    else
        ts.anynonpass = anynonpass(tc)
    end
    # Memoize for printing convenience
    return tc
end # function get_test_counts
    # if
end # if VERSION >= v"1.11.0-DEV.1529"

# anynonpass
if VERSION >= v"1.13.0-DEV.1037" # julia commit 364ecb3a11
    using .Test: anynonpass
else
    anynonpass(tc::TestCounts) = (tc.fails + tc.errors + tc.cumulative_fails + tc.cumulative_errors > 0)
    function anynonpass(ts::DefaultTestSet)
        tc = get_test_counts(ts)
        anynonpass(tc)
    end
end # if VERSION >= v"1.13.0-DEV.1037"

# insert_toplevel_latestworld
if VERSION >= v"1.12.0-DEV.1662" # julia commit 034e6093c5
    using .Test: insert_toplevel_latestworld
else
    insert_toplevel_latestworld(@nospecialize(tests)) = tests
end

if VERSION >= v"1.12.0-DEV.1812" # julia commit 6136893eee
    using .Test: get_rng, set_rng!
else
    using .Test: AbstractTestSet
    get_rng(ts::T) where {T <: AbstractTestSet} = hasfield(T, :rng) ? ts.rng : nothing
    set_rng!(ts::T, rng::Test.AbstractRNG) where {T <: AbstractTestSet} = hasfield(T, :rng) ? (ts.rng = rng) : rng
end

if VERSION >= v"1.13.0-DEV.731"
    using .Test: is_failfast_error
else
    is_failfast_error(err::FailFastError) = true
    is_failfast_error(err::LoadError) = is_failfast_error(err.error) # handle `include` barrier
    is_failfast_error(err) = false
end

if VERSION >= v"1.13.0-DEV.1044" # julia commit bb36851288
    using .Test: global_fail_fast
    using .Test: @with_testset
else
    if VERSION >= v"1.12" # OncePerProcess
        const global_fail_fast = OncePerProcess{Bool}() do
           return compat_get_bool_env("JULIA_TEST_FAILFAST", false)
       end
    else
        const global_fail_fast = () -> compat_get_bool_env("JULIA_TEST_FAILFAST", false)
    end
    using .Test: push_testset, pop_testset
    compat_push_testset = push_testset
    compat_pop_testset = pop_testset
    macro with_testset(ts, expr)
        quote
            print_testset_verbose(:enter, $(esc(ts)))
            try
                $(esc(expr))
            finally
                print_testset_verbose(:exit, $(esc(ts)))
            end
        end
    end
end # if


module compat_ScopedValues

if VERSION >= v"1.13.0-DEV.1044" # julia commit bb36851288
    using ..Test: CURRENT_TESTSET, TESTSET_DEPTH
    using Base.ScopedValues: LazyScopedValue, get
else
    using ..Test: FallbackTestSet, AbstractTestSet
    using ..Jive: compat_push_testset, compat_pop_testset
    abstract type AbstractScopedValue{T} end
    mutable struct LazyScopedValue{T} <: AbstractScopedValue{T}
        getdefault # ::OncePerProcess{T}
    end
    mutable struct ScopedValue{T} <: AbstractScopedValue{T}
        #= const =# has_default::Bool
        #= const =# default::T
        ScopedValue{T}(val) where T = new{T}(true, val)
    end
    const CURRENT_TESTSET = ScopedValue{AbstractTestSet}(FallbackTestSet())
    const TESTSET_DEPTH = ScopedValue{Int}(0)
    function get(val::AbstractScopedValue{T}) where {T}
        verbose::T = val.getdefault()
        verbose
    end
end # if

end # module Jive.compat_ScopedValues


if VERSION >= v"1.13.0-DEV.1075" # julia commit 0b39226110
    using .Test: VERBOSE_TESTSETS
    import .Test: print_testset_verbose
else
    using .compat_ScopedValues: CURRENT_TESTSET, TESTSET_DEPTH, LazyScopedValue
    const VERBOSE_TESTSETS = LazyScopedValue{Bool}() do # OncePerProcess{Bool}
        return compat_get_bool_env("JULIA_TEST_VERBOSE", false)
    end
end # if

function print_testset_verbose(action::Symbol, ts::DefaultTestSet)
    jive_print_testset_verbose(action, ts)
end

# testset_context
# @testset let
#
# v"1.9.0-DEV.1061" # 6f737f165e1c373cc8674bc8b5b4e345c1e915b9
# struct ContextTestSet <: AbstractTestSet
#-    context_sym::Symbol
#+    context_name::Union{Symbol, Expr}
#
# v"1.9.0-DEV.1055" # ff1b563e3c6f3ee419de0f792c5ff42744448f1c
# +struct ContextTestSet <: AbstractTestSet
#+    parent_ts::AbstractTestSet
#+    context_sym::Symbol
#+    context::Any
if VERSION >= v"1.9.0-DEV.1055" # julia commit ff1b563e3c
    compat_testset_context = Test.testset_context
    using .Test: ContextTestSet
    function print_testset_verbose(action::Symbol, ts::ContextTestSet)
        jive_print_testset_verbose(action, ts)
    end
else
    import .Test: record
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
end # function ContextTestSet
record(c::ContextTestSet, t) = record(c.parent_ts, t)
function record(c::ContextTestSet, t::Fail)
    context = string(c.context_name, " = ", c.context)
    if VERSION >= v"1.9.0-DEV.1055"
        context = t.context === nothing ? context : string(t.context, "\n              ", context)
    end
    if VERSION >= v"1.8.0-DEV.363"
        message_only = t.message_only
    else
        message_only = false
    end
    record(c.parent_ts, Fail(t.test_type, t.orig_expr, t.data, t.value, context, t.source, message_only))
end # function record
    # if

# Generate the code for an `@testset` with a `let` argument.
function _testset_context(args, ex, source)
    desc, testsettype, options = parse_testset_args(args[1:end-1])
    if desc !== nothing || testsettype !== nothing
        # Reserve this syntax if we ever want to allow this, but for now,
        # just do the transparent context test set.
        error("@testset with a `let` argument cannot be customized")
    end

    let_ex = ex.args[1]

    if Meta.isexpr(let_ex, :(=))
        contexts = Any[let_ex.args[1]]
    elseif Meta.isexpr(let_ex, :block)
        contexts = Any[]
        for assign_ex in let_ex.args
            if Meta.isexpr(assign_ex, :(=))
                push!(contexts, assign_ex.args[1])
            else
                error("Malformed `let` expression is given")
            end
        end
    else
        error("Malformed `let` expression is given")
    end
    reverse!(contexts)

    test_ex = ex.args[2]

    ex.args[2] = quote
        $(map(contexts) do context
            :($compat_push_testset($(ContextTestSet)($(QuoteNode(context)), $context; $options...)))
        end...)
        try
            $(test_ex)
        finally
            $(map(_->:($compat_pop_testset()), contexts)...)
        end
    end

    return esc(ex)
end # function _testset_context
    # if
    compat_testset_context = _testset_context
end # if VERSION >= v"1.9.0-DEV.1055" # _testset_context

# code from
# function Test.print_testset_verbose(action::Symbol, ts::AbstractTestSet)
function print_testset_summary(action::Symbol, ts::AbstractTestSet)
    env_verbose = something(compat_ScopedValues.get(VERBOSE_TESTSETS))
    !env_verbose && return
    depth_pad = get_testset_depth()
    indent = "  " ^ depth_pad
    desc = if hasfield(typeof(ts), :description)
        ts.description
    elseif isa(ts, ContextTestSet)
        string(ts.context_name, " = ", ts.context)
    else
        string(typeof(ts))
    end
    if action === :enter
        # println("$(indent)Starting testset: $desc")
    elseif action === :exit
        for rs in ts.results
            if rs isa AbstractTestSet
                print_test_results(rs, depth_pad)
            end
        end
        duration_str = ""
        # Calculate duration for testsets that have timing information
        if hasfield(typeof(ts), :time_start) && hasfield(typeof(ts), :showtiming)
            if ts.showtiming
                current_time = time()
                dur_s = current_time - ts.time_start
                if dur_s < 60
                    duration_str = " ($(round(dur_s, digits = 1))s)"
                else
                    m, s = divrem(dur_s, 60)
                    s = lpad(string(round(s, digits = 1)), 4, "0")
                    duration_str = " ($(round(Int, m))m$(s)s)"
                end
            end
        end
        # println("$(indent)Finished testset: $desc$duration_str")
    end
end # function print_testset_summary

### compat_get_bool_env
if VERSION >= v"1.11.0-DEV.1432"
    const compat_get_bool_env = Base.get_bool_env
else
    # from julia/base/env.jl
    const get_bool_env_truthy = (
        "t", "T",
        "true", "True", "TRUE",
        "y", "Y",
        "yes", "Yes", "YES",
        "1")
    const get_bool_env_falsy = (
        "f", "F",
        "false", "False", "FALSE",
        "n", "N",
        "no", "No", "NO",
        "0")
    function parse_bool_env(name::String, val::String = ENV[name]; throw::Bool=false)::Union{Nothing, Bool}
        if val in get_bool_env_truthy
            return true
        elseif val in get_bool_env_falsy
            return false
        elseif throw
            Base.throw(ArgumentError("Value for environment variable `$name` could not be parsed as Boolean: $(repr(val))"))
        else
            return nothing
        end
    end
    function compat_get_bool_env(name::String, default::Bool; kwargs...)::Union{Nothing, Bool}
        if haskey(ENV, name)
            val = ENV[name]
            if !isempty(val)
                return parse_bool_env(name, val; kwargs...)
            end
        end
        return default
    end
end # if VERSION >= v"1.11.0-DEV.1432"


if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" # _testset_forloop, _testset_beginend_call

# from julia/stdlib/Test/src/Test.jl  testset_forloop(args, testloop, source)
# v"1.13.0-DEV.864"  julia commit cdca6686574e6a079e7318e7f938460f29567fcb
#
# Generate the code for a `@testset` with a `for` loop argument
function _testset_forloop(args, testloop, source)
    # Pull out the loop variables. We might need them for generating the
    # description and we'll definitely need them for generating the
    # comprehension expression at the end
    loopvars = Expr[]
    if testloop.args[1].head === :(=)
        push!(loopvars, testloop.args[1])
    elseif testloop.args[1].head === :block
        for loopvar in testloop.args[1].args
            push!(loopvars, loopvar)
        end
    else
        error("Unexpected argument to @testset")
    end

    desc, testsettype, options = parse_testset_args(args[1:end-1])

    if desc === nothing
        # No description provided. Generate from the loop variable names
        v = loopvars[1].args[1]
        desc = Expr(:string, "$v = ", esc(v)) # first variable
        for l = loopvars[2:end]
            v = l.args[1]
            push!(desc.args, ", $v = ")
            push!(desc.args, esc(v))
        end
    end

    if testsettype === nothing
        testsettype = :(get_testset_depth() == 0 ? DefaultTestSet : typeof(get_testset()))
    end

    # Uses a similar block as for `@testset`, except that it is
    # wrapped in the outer loop provided by the user
    tests = testloop.args[2]
    blk = quote
        _check_testset($testsettype, $(QuoteNode(testsettype.args[1])))
        # Trick to handle `break` and `continue` in the test code before
        # they can be handled properly by `finally` lowering.
        if !first_iteration
            compat_pop_testset()
            finish_errored = true
            push!(arr, finish(ts))
            finish_errored = false
            copy!(default_rng(), tls_seed)
        end
        ts = if ($testsettype === $DefaultTestSet) && $(isa(source, LineNumberNode))
            $(testsettype)($desc; source=$(QuoteNode(source.file)), $options..., rng=tls_seed)
        else
            $(testsettype)($desc; $options...)
        end
        compat_push_testset(ts)
        first_iteration = false
        try
            $(esc(tests))
        catch err
            err isa InterruptException && rethrow()
            # Something in the test block threw an error. Count that as an
            # error in this test set
            trigger_test_failure_break(err)
            if is_failfast_error(err)
                get_testset_depth() > 1 ? rethrow() : failfast_print()
            else
                record(ts, Error(:nontest_error, Expr(:tuple), err, Base.current_exceptions(), $(QuoteNode(source)), nothing))
            end
        end
    end
    quote
        local arr = Vector{Any}()
        local first_iteration = true
        local ts
        local rng_option = get($(options), :rng, nothing)
        local finish_errored = false
        local default_rng_orig = copy(default_rng())
        local tls_seed_orig = copy(Random.get_tls_seed())
        local tls_seed = isnothing(rng_option) ? copy(Random.get_tls_seed()) : rng_option
        copy!(Random.default_rng(), tls_seed)
        try
            let
                $(Expr(:for, Expr(:block, [esc(v) for v in loopvars]...), blk))
            end
        finally
            # Handle `return` in test body
            if !first_iteration && !finish_errored
                compat_pop_testset()
                @assert @isdefined(ts) "Assertion to tell the compiler about the definedness of this variable"
                push!(arr, finish(ts))
            end
            copy!(default_rng(), default_rng_orig)
            copy!(Random.get_tls_seed(), tls_seed_orig)
        end
        arr
    end
end # function _testset_forloop(args, testloop, source)
    # if

# Generate the code for a `@testset` with a function call or `begin`/`end` argument
function _testset_beginend_call(args, tests, source)
    desc, testsettype, options = parse_testset_args(args[1:end-1])
    if desc === nothing
        if tests.head === :call
            desc = string(tests.args[1]) # use the function name as test name
        else
            desc = "test set"
        end
    end
    # If we're at the top level we'll default to DefaultTestSet. Otherwise
    # default to the type of the parent testset
    if testsettype === nothing
        testsettype = :(get_testset_depth() == 0 ? DefaultTestSet : typeof(get_testset()))
    end

    tests = insert_toplevel_latestworld(tests)

    # Generate a block of code that initializes a new testset, adds
    # it to the task local storage, evaluates the test(s), before
    # finally removing the testset and giving it a chance to take
    # action (such as reporting the results)
    ex = quote
        _check_testset($testsettype, $(QuoteNode(testsettype.args[1])))
        local ret
        local ts = if ($testsettype === $DefaultTestSet) && $(isa(source, LineNumberNode))
            $(testsettype)($desc; source=$(QuoteNode(source.file)), $options...)
        else
            $(testsettype)($desc; $options...)
        end
        compat_push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        local default_rng_orig = copy(default_rng())
        local tls_seed_orig = copy(Random.get_tls_seed())
        local tls_seed = isnothing(get_rng(ts)) ? set_rng!(ts, tls_seed_orig) : get_rng(ts)
        try
            @with_testset ts begin
                # default RNG is reset to its state from last `seed!()` to ease reproduce a failed test
                copy!(Random.default_rng(), tls_seed)
                copy!(Random.get_tls_seed(), Random.default_rng())
                let
                    $(esc(tests))
                end
            end
        catch err
            err isa InterruptException && rethrow()
            # something in the test block threw an error. Count that as an
            # error in this test set
            trigger_test_failure_break(err)
            if is_failfast_error(err)
                get_testset_depth() > 1 ? rethrow() : failfast_print()
            else
                record(ts, Error(:nontest_error, Expr(:tuple), err, Base.current_exceptions(), $(QuoteNode(source))))
            end
        finally
            copy!(default_rng(), default_rng_orig)
            copy!(Random.get_tls_seed(), tls_seed_orig)
            compat_pop_testset()
            ret = finish(ts)
        end
        ret
    end
    # preserve outer location if possible
    if tests isa Expr && tests.head === :block && !isempty(tests.args) && tests.args[1] isa LineNumberNode
        ex = Expr(:block, tests.args[1], ex)
    end
    return ex
end # function _testset_beginend_call(args, tests, source)
    # if
    compat_testset_forloop = _testset_forloop
    compat_testset_beginend_call = _testset_beginend_call
else # if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" # _testset_forloop, _testset_beginend_call
    compat_testset_forloop = Test.testset_forloop
    compat_testset_beginend_call = VERSION >= v"1.8.0-DEV.809" ? Test.testset_beginend_call : Test.testset_beginend
end # if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" # _testset_forloop, _testset_beginend_call

function default_testset_ignored_keys()::Set{Symbol}
    ignore_keys = Set{Symbol}()
    if VERSION < v"1.12.0-DEV.1812"
        push!(ignore_keys, :rng)
        if VERSION < v"1.9.0-DEV.623"
            push!(ignore_keys, :failfast)
            if VERSION < v"1.6.0-DEV.1437"
                push!(ignore_keys, :verbose)
            end
        end
    end
    ignore_keys
end # function default_testset_ignored_keys

function compat_default_testset(exprs...)
    ignore_keys = default_testset_ignored_keys()
    filter(expr -> !(expr.head === :(=) && expr.args[1] in ignore_keys), exprs)
end

import .Test: @testset
macro testset(expr::Expr...)
    args = compat_default_testset(expr...,)
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
end # macro testset(expr::Expr...)

# jive_testset_filter (global defined in runtests.jl)
macro testset(name::String, rest_args...)
    global jive_testset_filter
    if jive_testset_filter !== nothing
        !jive_testset_filter(name) && return nothing
    end

    args = (name, compat_default_testset(rest_args...)...)
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
end # macro testset(name::String, rest_args...)

# end # module Jive
