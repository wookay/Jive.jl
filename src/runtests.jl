# module Jive

"""
    runtests(dir::String)

run the test files from the specific directory.
"""
function runtests(dir::String)
    all_tests = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        for filename in files
            !endswith(filename, ".jl") && continue
            "runtests.jl" == filename && continue
            subpath = relpath(normpath(root, filename), dir)
            !isempty(ARGS) && !any(x->startswith(subpath, x), ARGS) && continue
            push!(all_tests, subpath)
        end
    end
    run(dir, all_tests)
end


# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl
module CodeFromStdlibTest

using Test: GLOBAL_RNG, TESTSET_PRINT_ENABLE, DefaultTestSet, Error, TestSetException, Random, get_testset_depth, get_testset, record, pop_testset, parse_testset_args, _check_testset, push_testset, get_test_counts, filter_errors

function jive_briefing(numbering, subpath, ts::DefaultTestSet)
    printstyled(numbering, color=:underline)
    println(' ', subpath)
end

# print_counts
function jive_print_counts(ts::DefaultTestSet)
    passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)

    np = passes + c_passes
    if np > 0
        print(repeat(' ', 4))
        printstyled("Pass", " "; bold=true, color=:green)
        printstyled(np, color=:green)
        println()
    end

    nf = fails + c_fails
    if nf > 0
        print(repeat(' ', 4))
        printstyled("Fail", " "; bold=true, color=Base.error_color())
        printstyled(nf, color=Base.error_color())
        println()
    end

    ne = errors + c_errors
    if ne > 0
        print(repeat(' ', 4))
        printstyled("Error", " "; bold=true, color=Base.error_color())
        printstyled(ne, color=Base.error_color())
        println()
    end

    nb = broken + c_broken
    if nb > 0
        print(repeat(' ', 4))
        printstyled("Broken", " "; bold=true, color=Base.warn_color())
        printstyled(nb, color=Base.warn_color())
        println()
    end
end

# finish
function jive_finish(ts::DefaultTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return ts
    end
    passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)
    total_pass   = passes + c_passes
    total_fail   = fails  + c_fails
    total_error  = errors + c_errors
    total_broken = broken + c_broken
    total = total_pass + total_fail + total_error + total_broken

    if TESTSET_PRINT_ENABLE[]
        jive_print_counts(ts) # print_test_results(ts)
    end

    # Finally throw an error as we are the outermost test set
    if total != total_pass + total_broken
        # Get all the error/failures and bring them along for the ride
        efs = filter_errors(ts)
        throw(TestSetException(total_pass,total_fail,total_error, total_broken, efs))
    end

    # return the testset so it is returned from the @testset macro
    ts
end

# testset_beginend
function jive_testset_beginend(numbering, subpath, args, tests, source)
    desc, testsettype, options = parse_testset_args(args[1:end-1])
    if desc === nothing
        desc = "test set"
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
        ts = $(testsettype)($desc; $options...)
        jive_briefing($(esc(numbering)), $(esc(subpath)), ts)
        # this empty loop is here to force the block to be compiled,
        # which is needed for backtrace scrubbing to work correctly.
        while false; end
        push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        oldrng = copy(GLOBAL_RNG)
        try
            # GLOBAL_RNG is re-seeded with its own seed to ease reproduce a failed test
            Random.seed!(GLOBAL_RNG.seed)
            $(esc(tests))
        catch err
            err isa InterruptException && rethrow()
            # something in the test block threw an error. Count that as an
            # error in this test set
            record(ts, Error(:nontest_error, :(), err, catch_backtrace(), $(QuoteNode(source))))
        finally
            copy!(GLOBAL_RNG, oldrng)
        end
        pop_testset()
        jive_finish(ts) # finish(ts)
    end
    # preserve outer location if possible
    if tests isa Expr && tests.head === :block && !isempty(tests.args) && tests.args[1] isa LineNumberNode
        ex = Expr(:block, tests.args[1], ex)
    end
    return ex
end

# @testset
macro jive_testset(numbering, subpath, args...)
    tests = args[end]
    return jive_testset_beginend(numbering, subpath, args, tests, __source__)
end

end # module CodeFromStdlibTest


using .CodeFromStdlibTest: @jive_testset

function run(dir::String, tests::Vector{String})
    n_passed = 0
    anynonpass = 0
    for (idx, subpath) in enumerate(tests)
        filepath = normpath(dir, subpath) 
        numbering = string(idx, /, length(tests))
        ts = @jive_testset numbering subpath "" begin
            Main.include(filepath)
        end
        n_passed += ts.n_passed
        anynonpass += ts.anynonpass
    end
    if iszero(anynonpass) && n_passed > 0
        printstyled("✅  ", color=:green)
        print("All ")
        printstyled(n_passed, color=:green)
        print(" ")
        print(n_passed == 1 ? "test has" : "tests have")
        print(" been completed.")
        println()
    end
end

# module Jive
