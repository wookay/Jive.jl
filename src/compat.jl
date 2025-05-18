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
