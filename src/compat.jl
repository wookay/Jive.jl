# module Jive

# 0.7.0-DEV.1995
using .Test: parse_testset_args

if VERSION >= v"1.9.0-DEV.623"
    using .Test: FailFastError, FAIL_FAST
else
    struct FailFastError <: Exception end
    FAIL_FAST = Ref{Bool}(false) # compat_get_bool_env("JULIA_TEST_FAILFAST", false)
end

if VERSION >= v"1.13.0-DEV.731"
    using .Test: is_failfast_error
else
    is_failfast_error(err::FailFastError) = true
    is_failfast_error(err::LoadError) = is_failfast_error(err.error) # handle `include` barrier
    is_failfast_error(err) = false
end


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

if VERSION >= v"1.9.0-DEV.228"
    using .Test: trigger_test_failure_break
else
    trigger_test_failure_break(@nospecialize(err)) = ccall(:jl_test_failure_breakpoint, Cvoid, (Any,), err)
end

using .Test: Error
if VERSION >= v"1.13.0-DEV.769" # julia commit 76d5b14c9c280c52b2c275e6cf449fe1ba7fc8d2
    # Internal constructor for creating Error with pre-processed values (used by ContextTestSet)
    # function Error(test_type::Symbol, orig_expr::String, value::String, backtrace::String, context::Union{Nothing, String}, source::LineNumberNode)
    #     return new(test_type, orig_expr, value, backtrace, context, source)
    # end
else
    # FIXME: how to access the internal constructor for creating Error
end


if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" # _testset_forloop, _testset_beginend_call

if VERSION >= v"1.12.0-DEV.1662" # julia commit 034e6093c53ce2aae989045cfd5942dade27198b
    using .Test: insert_toplevel_latestworld
else
    insert_toplevel_latestworld(@nospecialize(tests)) = tests
end

if VERSION >= v"1.12.0-DEV.1812" # julia commit 6136893eeed0c3559263a5aa465b630d2c7dc821
    using .Test: get_rng, set_rng!
else
    using .Test: AbstractTestSet, DefaultTestSet, AbstractRNG
    get_rng(::AbstractTestSet) = nothing
    get_rng(ts::DefaultTestSet) = nothing
    set_rng!(::AbstractTestSet, rng::AbstractRNG) = rng
    set_rng!(ts::DefaultTestSet, rng::AbstractRNG) = rng
end

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
            pop_testset()
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
        push_testset(ts)
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
                record(ts, Error(:nontest_error, Expr(:tuple), err, Base.current_exceptions(), $(QuoteNode(source))))
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
                pop_testset()
                push!(arr, finish(ts))
            end
            copy!(default_rng(), default_rng_orig)
            copy!(Random.get_tls_seed(), tls_seed_orig)
        end
        arr
    end
end # function _testset_forloop(args, testloop, source)

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
        push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        local default_rng_orig = copy(default_rng())
        local tls_seed_orig = copy(Random.get_tls_seed())
        local tls_seed = isnothing(get_rng(ts)) ? set_rng!(ts, tls_seed_orig) : get_rng(ts)
        try
            # default RNG is reset to its state from last `seed!()` to ease reproduce a failed test
            copy!(Random.default_rng(), tls_seed)
            copy!(Random.get_tls_seed(), Random.default_rng())
            let
                $(esc(tests))
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
            pop_testset()
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
    compat_testset_forloop = _testset_forloop
    compat_testset_beginend_call = _testset_beginend_call
else
    compat_testset_forloop = Test.testset_forloop
    compat_testset_beginend_call = VERSION >= v"1.8.0-DEV.809" ? Test.testset_beginend_call : Test.testset_beginend
end # if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" # _testset_forloop, _testset_beginend_call


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
if VERSION >= v"1.9.0-DEV.1055"
    using .Test: Fail
else
    import .Test: Fail
    function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool, backtrace=nothing)
        Fail(test_type, orig_expr, data, value, source)
    end
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
if VERSION >= v"1.9.0-DEV.1055"
    compat_testset_context = Test.testset_context
else
    using .Test: AbstractTestSet
    import .Test: record

# from julia/stdlib/Test/src/Test.jl
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
    if VERSION >= v"1.9.0-DEV.1055"
        context = t.context === nothing ? context : string(t.context, "\n              ", context)
    end
    if VERSION >= v"1.8.0-DEV.363"
        message_only = t.message_only
    else
        message_only = false
    end
    record(c.parent_ts, Fail(t.test_type, t.orig_expr, t.data, t.value, context, t.source, message_only))
end

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
            :($push_testset($(ContextTestSet)($(QuoteNode(context)), $context; $options...)))
        end...)
        try
            $(test_ex)
        finally
            $(map(_->:($pop_testset()), contexts)...)
        end
    end

    return esc(ex)
end
    compat_testset_context = _testset_context
end # if VERSION >= v"1.9.0-DEV.1055" # _testset_context

function compat_scrub_backtrace(bt, file_ts, file_t)
    if VERSION >= v"1.10.0-DEV.1171"
        scrub_backtrace(bt, file_ts, file_t)
    else
        scrub_backtrace(bt)
    end
end

compat_get_bool_env =
    if VERSION >= v"1.11.0-DEV.1432"
        Base.get_bool_env
    else
        function get_bool_env(name::String, default::Bool)::Bool
            if haskey(ENV, name)
                parse(Bool, getindex(ENV, name))
            else
                default
            end
        end
    end

# end # module Jive
