# module Jive

using Distributed # nprocs addprocs

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
            if !isempty(ARGS)
                sep = Base.Filesystem.path_separator
                !any(x -> startswith(subpath, (occursin('/', x) && sep != "/") ? replace(x, "/" => sep) : x), ARGS) && continue
            end
            push!(all_tests, subpath)
        end
    end
    env_jive_procs = get(ENV, "JIVE_PROCS", "") # "" "auto" "0" "1" "2" "3" ...
    if "0" == env_jive_procs
        run(dir, all_tests)
    else
        num_procs = nprocs()
        if isempty(env_jive_procs)
        elseif "auto" == env_jive_procs
            Sys.CPU_THREADS > num_procs && addprocs(Sys.CPU_THREADS - num_procs + 1)
        else
            jive_procs = parse(Int, env_jive_procs)
            jive_procs >= num_procs && addprocs(jive_procs - num_procs + 1)
        end
        if nprocs() > 1
            distributed_run(dir, all_tests)
        else
            run(dir, all_tests)
        end
    end
end

function report(io::IO, t0, anynonpass, n_passed)
    if iszero(anynonpass) && n_passed > 0
        printstyled(io, "✅  ", color=:green)
        print(io, "All ")
        printstyled(io, n_passed, color=:green)
        print(io, " ")
        print(io, n_passed == 1 ? "test has" : "tests have")
        print(io, " been completed.")
        Base.Printf.@printf(io, "  (%.2f seconds)\n", (time_ns()-t0)/1e9)
    end
end


# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl
module CodeFromStdlibTest

using Test: GLOBAL_RNG, TESTSET_PRINT_ENABLE, DefaultTestSet, Error, TestSetException, Random, get_testset_depth, get_testset, record, pop_testset, parse_testset_args, _check_testset, push_testset, get_test_counts, filter_errors

function jive_briefing(io::IO, numbering, subpath, ts::DefaultTestSet)
    printstyled(io, numbering, color=:underline)
    print(io, ' ', subpath)
    !isempty(ts.description) && print(io, ' ', ts.description)
    println(io)
end

# print_counts
function jive_print_counts(io::IO, ts::DefaultTestSet, elapsedtime)
    passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)

    nf = fails + c_fails
    if nf > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Fail", " "; bold=true, color=Base.error_color())
        printstyled(io, nf, color=Base.error_color())
        println(io)
    end

    ne = errors + c_errors
    if ne > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Error", " "; bold=true, color=Base.error_color())
        printstyled(io, ne, color=Base.error_color())
        println(io)
    end

    nb = broken + c_broken
    if nb > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Broken", " "; bold=true, color=Base.warn_color())
        printstyled(io, nb, color=Base.warn_color())
        println(io)
    end

    np = passes + c_passes
    if np > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Pass", " "; bold=true, color=:green)
        printstyled(io, np, color=:green)
        Base.Printf.@printf(io, "  (%.2f seconds)\n", elapsedtime)
    end
end

# finish
function jive_finish(io::IO, ts::DefaultTestSet, elapsedtime)
    #Base.timev_print(t, memallocs)
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
        jive_print_counts(io, ts, elapsedtime) # print_test_results(ts)
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
function jive_testset_beginend(io, numbering, subpath, args, tests, source)
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
        jive_briefing($(esc(io)), $(esc(numbering)), $(esc(subpath)), ts)
        # this empty loop is here to force the block to be compiled,
        # which is needed for backtrace scrubbing to work correctly.
        while false; end
        push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        oldrng = copy(GLOBAL_RNG)
        elapsedtime = @elapsed try
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
        jive_finish($(esc(io)), ts, elapsedtime) # finish(ts)
    end
    # preserve outer location if possible
    if tests isa Expr && tests.head === :block && !isempty(tests.args) && tests.args[1] isa LineNumberNode
        ex = Expr(:block, tests.args[1], ex)
    end
    return ex
end

# @testset
macro jive_testset(io, numbering, subpath, args...)
    tests = args[end]
    return jive_testset_beginend(io, numbering, subpath, args, tests, __source__)
end

end # module CodeFromStdlibTest


# code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl
module CodeFromJuliaTest

using ..CodeFromStdlibTest: @jive_testset
using ..Jive: report
using Test.Random # RandomDevice
using Distributed # @everywhere remotecall_fetch

function runner(worker, idx, num_tests, subpath, filepath)
    numbering = string(idx, /, num_tests)
    buf = IOBuffer()
    context = IOContext(buf, :color => true)
    ts = @jive_testset context numbering subpath " (worker: $worker)" begin
        Main.include(filepath)
    end
    (ts, buf)
end

function distributed_run(dir::String, tests::Vector{String})
    io = stdout
    printstyled(io, "Sys.CPU_THREADS", color=:cyan)
    printstyled(io, ": ", Sys.CPU_THREADS)
    printstyled(io, ", ")
    printstyled(io, "nworkers()", color=:cyan)
    printstyled(io, ": ", nworkers())
    println(io)

    idx = 0
    num_tests = length(tests)
    @everywhere @eval(Main, using Jive)
    n_passed = 0
    anynonpass = 0
    local t0 = time_ns()
    @sync begin
        for worker in workers()
            @async begin
                while length(tests) > 0
                    idx += 1
                    subpath = popfirst!(tests)
                    filepath = normpath(dir, subpath)
                    f = remotecall(runner, worker, worker, idx, num_tests, subpath, filepath)
                    (ts, buf) = fetch(f)
                    print(io, String(take!(buf)))
                    n_passed += ts.n_passed
                    anynonpass += ts.anynonpass
                end
            end
        end
    end
    report(io, t0, anynonpass, n_passed)
end

end # module CodeFromJuliaTest

using .CodeFromJuliaTest: distributed_run
using .CodeFromStdlibTest: @jive_testset

function run(dir::String, tests::Vector{String})
    io = stdout
    n_passed = 0
    anynonpass = 0
    local t0 = time_ns()
    for (idx, subpath) in enumerate(tests)
        filepath = normpath(dir, subpath) 
        numbering = string(idx, /, length(tests))
        ts = @jive_testset io numbering subpath "" begin
            Main.include(filepath)
        end
        n_passed += ts.n_passed
        anynonpass += ts.anynonpass
    end
    report(io, t0, anynonpass, n_passed)
end

# module Jive
