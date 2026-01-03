module TestExt

# @test context Ext
# VERSION >= v"1.11"

if VERSION >= v"1.14.0-DEV.1453" # julia commit 243155034fe2301bc1bed2e05a335c9665926390
    using Test: @test
elseif VERSION >= v"1.11"
    using Test: test_expr!, get_test_result, record, get_testset, do_broken_test, trigger_test_failure_break,
                Returned, ExecutionResult, Pass, Fail, Error, Threw
    import Test: @test

# from julia/stdlib/Test/src/Test.jl
# macro test(ex, kws...)
macro test(ex, kws::Expr...)
    # Collect the broken/skip/context keywords and remove them from the rest of keywords
    broken = [kw.args[2] for kw in kws if kw.args[1] === :broken]
    skip = [kw.args[2] for kw in kws if kw.args[1] === :skip]
    context = [kw.args[2] for kw in kws if kw.args[1] === :context]
    kws = filter(kw -> kw.args[1] ∉ (:skip, :broken, :context), kws)
    # Validation of broken/skip/context keywords
    for (kw, name) in ((broken, :broken), (skip, :skip), (context, :context))
        if length(kw) > 1
            error("invalid test macro call: cannot set $(name) keyword multiple times")
        end
    end
    if length(skip) > 0 && length(broken) > 0
        error("invalid test macro call: cannot set both skip and broken keywords")
    end

    # Build the test expression
    test_expr!("@test", ex, kws...)

    result = get_test_result(ex, __source__)

    ex = Expr(:inert, ex)
    ctx = length(context) > 0 ? esc(context[1]) : nothing
    result = quote
        if $(length(skip) > 0 && esc(skip[1]))
            record(get_testset(), Broken(:skipped, $ex))
        else
            let _do = $(length(broken) > 0 && esc(broken[1])) ? do_broken_test : do_test_ext
                _do($result, $ex, $ctx)
            end
        end
    end
    return result
end # macro test(ex, kws...)

# function do_test(result::ExecutionResult, @nospecialize(orig_expr), context=nothing)
function do_test_ext(result::ExecutionResult, @nospecialize(orig_expr), context=nothing)
    # get_testset() returns the most recently added test set
    # We then call record() with this test set and the test result
    context_str = context === nothing ? nothing : sprint(show, context; context=:limit => true)
    if isa(result, Returned)
        # expr, in the case of a comparison, will contain the
        # comparison with evaluated values of each term spliced in.
        # For anything else, just contains the test expression.
        # value is the evaluated value of the whole test expression.
        # Ideally it is true, but it may be false or non-Boolean.
        value = result.value
        testres = if isa(value, Bool)
            # a true value Passes
            value ? Pass(:test, orig_expr, result.data, value, result.source) :
                    Fail(:test, orig_expr, result.data, value, context_str, result.source, false)
        else
            # If the result is non-Boolean, this counts as an Error
            Error(:test_nonbool, orig_expr, value, nothing, result.source, context_str)
        end
    else
        # The predicate couldn't be evaluated without throwing an
        # exception, so that is an Error and not a Fail
        @assert isa(result, Threw)
        testres = Error(:test_error, orig_expr, result.exception, result.current_exceptions, result.source, context_str)
    end
    isa(testres, Pass) || trigger_test_failure_break(result)
    record(get_testset(), testres)
end # function do_test

# function Base.show(io::IO, t::Fail)
function Base.show(io::Base.TTY, t::Fail)
    printstyled(io, "Test Failed"; bold=true, color=Base.error_color())
    print(io, " at ")
    printstyled(io, something(t.source.file, :none), ":", t.source.line, "\n"; bold=true, color=:default)
    print(io, "  Expression: ", t.orig_expr)
    value, data = t.value, t.data
    if t.test_type === :test_throws_wrong
        # An exception was thrown, but it was of the wrong type
        if t.message_only
            print(io, "\n    Expected: ", data)
            print(io, "\n     Message: ", value)
        else
            print(io, "\n    Expected: ", data)
            print(io, "\n      Thrown: ", value)
            print(io, "\n")
            if t.backtrace !== nothing
                # Capture error message and indent to match
                join(io, ("      " * line for line in filter!(!isempty, split(t.backtrace, "\n"))), "\n")
            end
        end
    elseif t.test_type === :test_throws_nothing
        # An exception was expected, but no exception was thrown
        print(io, "\n    Expected: ", data)
        print(io, "\n  No exception thrown")
    elseif t.test_type === :test
        if data !== nothing && t.orig_expr != data
            # The test was an expression, so display the term-by-term
            # evaluated version as well
            print(io, "\n   Evaluated: ", data)
        end
    end
    if t.context !== nothing
        print(io, "\n     Context: ", t.context)
    end
end # function Base.show

end # if v"1.14.0-DEV.1453" >= VERSION

end # module TestExt
