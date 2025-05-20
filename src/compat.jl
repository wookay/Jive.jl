# module Jive

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

testset_beginend_call = VERSION >= v"1.8.0-DEV.809" ? Test.testset_beginend_call : Test.testset_beginend
trigger_test_failure_break = VERSION >= v"1.9.0-DEV.228" ? Test.trigger_test_failure_break : (err) -> nothing

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
elseif VERSION >= v"1.6.0-DEV.1148"
    import .Test: Fail
    function Fail(test_type::Symbol, orig_expr, data, value, context, source::LineNumberNode, message_only::Bool, backtrace=nothing)
        Fail(test_type, orig_expr, data, value, source)
    end
else
    using .Test: Fail
    # get the Long-term support (LTS) version
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
    testset_context = Test.testset_context
else
    using .Test: parse_testset_args, AbstractTestSet
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

"""
Generate the code for an `@testset` with a `let` argument.
"""
function testset_context(args, ex, source)
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
end # if VERSION >= v"1.9.0-DEV.1055" # testset_context


compat_extract_file =
    if VERSION >= v"1.10.0-DEV.1171"
        Test.extract_file
    else
        extract_file(source::LineNumberNode) = extract_file(source.file)
        extract_file(file::Symbol) = string(file)
        extract_file(::Nothing) = nothing
        extract_file
    end

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


if VERSION >= v"1.9.0-DEV.623"
    using .Test: FailFastError, FAIL_FAST
else
    struct FailFastError <: Exception end
    FAIL_FAST = Ref{Bool}(false) # compat_get_bool_env("JULIA_TEST_FAILFAST", false)
end

# end # module Jive
