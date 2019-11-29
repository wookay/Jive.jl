# module Jive

using Distributed # nprocs addprocs rmprocs
using Printf

function slash_to_path_separator(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, "/" => sep)
end

function path_separator_to_slash(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, sep => "/")
end

function get_all_files(dir, skip, targets)
    all_files = Vector{String}()
    filters = []
    start_idx = 1
    if !isempty(targets)
        for arg in targets
            if occursin('=', arg)
                name, val = split(arg, '=')
                if name == "start"
                    start_idx = parse(Int, val)
                end
            else
                subpath = path_separator_to_slash(arg)
                if subpath == "."
                elseif startswith(subpath, "./")
                    push!(filters, subpath[3:end])
                else
                    push!(filters, subpath)
                end
            end
        end
    end
    for (root, dirs, files) in walkdir(dir)
        for filename in files
            !endswith(filename, ".jl") && continue
            root == dir && "runtests.jl" == filename && continue
            subpath = path_separator_to_slash(relpath(normpath(root, filename), dir))
            any(x -> startswith(subpath, x), path_separator_to_slash.(skip)) && continue
            !isempty(filters) && !any(x -> startswith(subpath, x), filters) && continue
            push!(all_files, subpath)
        end
    end
    (all_files, start_idx)
end

"""
    runtests(dir::String; skip::Union{Vector{Any},Vector{String}}=[], node1::Union{Vector{Any},Vector{String}}=[], targets=ARGS, enable_distributed::Bool=true)

run the test files from the specific directory.

* `dir`: the root directory to traverse.
* `skip`: files or directories to skip.
* `node1`: run on node 1 during for the distributed tests.
* `targets`: filter targets and start. default is `ARGS`
* `enable_distributed`: option for distributed
"""
function runtests(dir::String; skip::Union{Vector{Any},Vector{String}}=[], node1::Union{Vector{Any},Vector{String}}=[], targets=ARGS, enable_distributed::Bool=true)
    (all_tests, start_idx) = get_all_files(dir, skip, targets)
    env_jive_procs = get(ENV, "JIVE_PROCS", "") # "" "auto" "0" "1" "2" "3" ...
    if ("0" == env_jive_procs) || !enable_distributed
        run(dir, all_tests, start_idx)
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
            distributed_run(dir, all_tests, start_idx, path_separator_to_slash.(node1))
        else
            run(dir, all_tests, start_idx)
        end
    end
end

struct FinishedWithErrors <: Exception
end

function Base.showerror(io::IO, ex::FinishedWithErrors, bt; backtrace=true)
    printstyled(io, "Test run finished with errors", color=:red)
end

function report(io::IO, t0, anynonpass, n_passed)
    if anynonpass > 0
        printstyled(io, "❗️  ", color=:red)
        print(io, "Test run finished with ")
        print(io, anynonpass, " ")
        print(io, anynonpass == 1 ? "error" : "errors", ".")
        Printf.@printf(io, "  (%.2f seconds)\n", (time_ns()-t0)/1e9)
        throw(FinishedWithErrors())
    elseif n_passed > 0
        printstyled(io, "✅  ", color=:green)
        print(io, "All ")
        printstyled(io, n_passed, color=:green)
        print(io, " ")
        print(io, n_passed == 1 ? "test has" : "tests have")
        print(io, " been completed.")
        Printf.@printf(io, "  (%.2f seconds)\n", (time_ns()-t0)/1e9)
    end
end

function jive_briefing(io::IO, numbering, subpath, msg, description)
    buf = IOBuffer()
    context = IOContext(buf, :color => true)
    printstyled(context, numbering, color=:underline)
    print(context, ' ', subpath)
    !isempty(msg) && print(context, ' ', msg)
    println(context)
    print(io, String(take!(buf)))
end

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl
module CodeFromStdlibTest

using Test: TESTSET_PRINT_ENABLE, DefaultTestSet, Error, TestSetException, Random, get_testset_depth, get_testset, record, pop_testset, parse_testset_args, _check_testset, push_testset, get_test_counts, filter_errors
using ..Jive: jive_briefing
using Printf

if VERSION >= v"1.3.0-DEV.565"
    default_rng = Random.default_rng
else
    default_rng = () -> Random.GLOBAL_RNG
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
        Printf.@printf(io, "  (%.2f seconds)\n", elapsedtime)
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
function jive_testset_beginend(io, numbering, subpath, msg, args, tests, source)
    desc, testsettype, options = parse_testset_args(args[1:end-1])
    if desc === nothing
        desc = ""
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
        jive_briefing($(esc(io)), $(esc(numbering)), $(esc(subpath)), $(esc(msg)), ts.description)
        # this empty loop is here to force the block to be compiled,
        # which is needed for backtrace scrubbing to work correctly.
        while false; end
        push_testset(ts)
        # we reproduce the logic of guardseed, but this function
        # cannot be used as it changes slightly the semantic of @testset,
        # by wrapping the body in a function
        local RNG = default_rng()
        oldrng = copy(RNG)
        elapsedtime = @elapsed try
            # RNG is re-seeded with its own seed to ease reproduce a failed test
            Random.seed!(RNG.seed)
            $(esc(tests))
        catch err
            err isa InterruptException && rethrow()
            # something in the test block threw an error. Count that as an
            # error in this test set
            backtrace = VERSION >= v"1.2.0-DEV.459" ? Base.catch_stack() : stacktrace(catch_backtrace())
            record(ts, Error(:nontest_error, :(), err, backtrace, LineNumberNode(err.line, err.file)))
        finally
            copy!(RNG, oldrng)
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
macro jive_testset(io, numbering, subpath, msg, args...)
    tests = args[end]
    return jive_testset_beginend(io, numbering, subpath, msg, args, tests, __source__)
end

end # module Jive.CodeFromStdlibTest


# code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl
module CodeFromJuliaTest

using ..CodeFromStdlibTest: @jive_testset, get_test_counts
using ..Jive: slash_to_path_separator, report, jive_briefing
using Test.Random # RandomDevice
using Distributed # @everywhere remotecall_fetch

function runner(worker, idx, num_tests, subpath, filepath)
    numbering = string(idx, /, num_tests)
    buf = IOBuffer()
    context = IOContext(buf, :color => true)
    ts = @jive_testset context numbering subpath " (worker: $worker)" "" begin
        Main.include(filepath)
    end
    (ts, buf)
end

function distributed_run(dir::String, tests::Vector{String}, start_idx::Int, node1::Vector{String})
    io = stdout
    printstyled(io, "Sys.CPU_THREADS", color=:cyan)
    printstyled(io, ": ", Sys.CPU_THREADS)
    printstyled(io, ", ")
    printstyled(io, "nworkers()", color=:cyan)
    printstyled(io, ": ", nworkers())
    println(io)

    idx = 0
    num_tests = length(tests)
    env = Dict{Int,Tuple{Int,String}}()

    n_passed = 0
    anynonpass = 0
    local t0 = time_ns()
    try
        node1_tests = []
        @everywhere @eval(Main, using Jive)
        @sync begin
            for worker in workers()
                @async begin
                    while length(tests) > 0
                        idx += 1
                        subpath = popfirst!(tests)
                        env[worker] = (idx, subpath)
                        if idx < start_idx
                            numbering = string(idx, /, num_tests)
                            jive_briefing(io, numbering, subpath, "--", "")
                            continue
                        end
                        if any(x -> startswith(subpath, x), node1)
                            push!(node1_tests, (idx, subpath))
                        else
                            filepath = normpath(dir, slash_to_path_separator(subpath))
                            f = remotecall(runner, worker, worker, idx, num_tests, subpath, filepath)
                            (ts, buf) = fetch(f)
                            print(io, String(take!(buf)))
                            passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)
                            n_passed += passes + c_passes
                            anynonpass += ts.anynonpass
                        end
                    end # while length(tests) > 0
                    if worker != 1
                        # Free up memory =)
                        rmprocs(worker, waitfor=0)
                    end
                end # @async begin
            end # for worker in workers()
        end # @sync begin
        worker = myid()
        for (idx, subpath) in node1_tests
            filepath = normpath(dir, slash_to_path_separator(subpath))
            f = remotecall(runner, worker, worker, idx, num_tests, subpath, filepath)
            (ts, buf) = fetch(f)
            print(io, String(take!(buf)))
            passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)
            n_passed += passes + c_passes
            anynonpass += ts.anynonpass
        end
    catch err
        anynonpass += 1
        print(io, "⚠️  ")
        if err isa CompositeException
            exception = first(err.exceptions)
            if exception isa CapturedException
                result = exception.ex
            elseif Symbol(typeof(exception)) === :TaskFailedException  # VERSION >= v"1.3.0-alpha.110"
                result = exception.task.result
            else
                result = nothing
            end
            if result isa RemoteException
                remote_worker = result.pid
                if haskey(env, remote_worker)
                    (idx, subpath) = env[remote_worker]
                    numbering = string(idx, /, num_tests)
                    jive_briefing(io, numbering, subpath, " (worker: $remote_worker)", "")
                end
                print(io, ": ")
                println.(Ref(io), result.captured.ex.errors_and_fails)
            else
                showerror(io, exception)
                println(io)
            end
        else
            showerror(io, err)
            println(io)
        end
    finally
        GC.gc()
    end
    report(io, t0, anynonpass, n_passed)
end

end # module Jive.CodeFromJuliaTest


using .CodeFromJuliaTest: distributed_run
using .CodeFromStdlibTest: @jive_testset, get_test_counts

function run(dir::String, tests::Vector{String}, start_idx::Int)
    io = stdout
    n_passed = 0
    anynonpass = 0
    local t0 = time_ns()
    for (idx, subpath) in enumerate(tests)
        if idx < start_idx
            num_tests = length(tests)
            numbering = string(idx, /, num_tests)
            jive_briefing(io, numbering, subpath, "--", "")
            continue
        end
        filepath = normpath(dir, slash_to_path_separator(subpath))
        numbering = string(idx, /, length(tests))
        ts = @jive_testset io numbering subpath "" "" begin
            Main.include(filepath)
        end
        passes, fails, errors, broken, c_passes, c_fails, c_errors, c_broken = get_test_counts(ts)
        n_passed += passes + c_passes
        anynonpass += ts.anynonpass
    end
    report(io, t0, anynonpass, n_passed)
end

# module Jive
