# module Jive

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

macro testset_for_julia_v15(args...)
    isempty(args) && error("No arguments to @testset")

    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests,Expr) || (tests.head !== :for && tests.head !== :block && tests.head != :call)

        error("Expected function call, begin/end block or for loop as argument to @testset")
    end

    if tests.head === :for
        return v15_testset_forloop(args, tests, __source__)
    else
        return v15_testset_beginend_call(args, tests, __source__)
    end
end

GLOBAL_SEED = 0
set_global_seed!(seed) = global GLOBAL_SEED = seed

"""
Generate the code for a `@testset` with a `begin`/`end` argument
"""
function v15_testset_beginend_call(args, tests, source)
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

    # Generate a block of code that initializes a new testset, adds
    # it to the task local storage, evaluates the test(s), before
    # finally removing the testset and giving it a chance to take
    # action (such as reporting the results)
    ex = quote
        _check_testset($testsettype, $(QuoteNode(testsettype.args[1])))
        local ret
        local ts = $(testsettype)($desc; $options...)
        push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        local RNG = default_rng()
        local oldrng = copy(RNG)
        local oldseed = GLOBAL_SEED
        try
            # RNG is re-seeded with its own seed to ease reproduce a failed test
            Random.seed!(GLOBAL_SEED)
            let
                $(esc(tests))
            end
        catch err
            err isa InterruptException && rethrow()
            # something in the test block threw an error. Count that as an
            # error in this test set
            trigger_test_failure_break(err)
            record(ts, Error(:nontest_error, Expr(:tuple), err, Base.current_exceptions(), $(QuoteNode(source))))
        finally
            copy!(RNG, oldrng)
            set_global_seed!(oldseed)
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
end


"""
Generate the code for a `@testset` with a `for` loop argument
"""
function v15_testset_forloop(args, testloop, source)
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
            push!(arr, finish(ts))
            # it's 1000 times faster to copy from tmprng rather than calling Random.seed!
            copy!(RNG, tmprng)

        end
        ts = $(testsettype)($desc; $options...)
        push_testset(ts)
        first_iteration = false
        try
            $(esc(tests))
        catch err
            err isa InterruptException && rethrow()
            # Something in the test block threw an error. Count that as an
            # error in this test set
            trigger_test_failure_break(err)
            record(ts, Error(:nontest_error, Expr(:tuple), err, Base.current_exceptions(), $(QuoteNode(source))))
        end
    end
    quote
        local arr = Vector{Any}()
        local first_iteration = true
        local ts
        local RNG = default_rng()
        local oldrng = copy(RNG)
        local oldseed = GLOBAL_SEED
        Random.seed!(GLOBAL_SEED)
        local tmprng = copy(RNG)
        try
            let
                $(Expr(:for, Expr(:block, [esc(v) for v in loopvars]...), blk))
            end
        finally
            # Handle `return` in test body
            if !first_iteration
                pop_testset()
                push!(arr, finish(ts))
            end
            copy!(RNG, oldrng)
            set_global_seed!(oldseed)
        end
        arr
    end
end

"""
Parse the arguments to the `@testset` macro to pull out the description,
Testset Type, and options. Generally this should be called with all the macro
arguments except the last one, which is the test expression itself.
"""
function parse_testset_args(args)
    desc = nothing
    testsettype = nothing
    options = :(Dict{Symbol, Any}())
    for arg in args
        # a standalone symbol is assumed to be the test set we should use
        if isa(arg, Symbol)
            testsettype = esc(arg)
        # a string is the description
        elseif isa(arg, AbstractString) || (isa(arg, Expr) && arg.head === :string)
            desc = esc(arg)
        # an assignment is an option
        elseif isa(arg, Expr) && arg.head === :(=)
            # we're building up a Dict literal here
            key = Expr(:quote, arg.args[1])
            push!(options.args, Expr(:call, :(=>), key, esc(arg.args[2])))
        else
            error("Unexpected argument $arg to @testset")
        end
    end

    (desc, testsettype, options)
end

# module Jive
