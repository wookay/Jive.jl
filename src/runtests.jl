# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl

using Test: Test, Random
using Distributed: Distributed, nprocs, nworkers, addprocs, rmprocs, workers
using Printf: Printf

include("runtests_distributed_run.jl")
include("runtests_code_from_stdlib_Test.jl")

# compat
default_rng = begin
    if VERSION >= v"1.3.0-DEV.565"
        Random.default_rng
    else
        () -> Random.GLOBAL_RNG
    end
end

cumulative_compile_time_ns_before, cumulative_compile_time_ns_after = begin
    if VERSION >= v"1.6.0-DEV.1819" && isdefined(Base, :cumulative_compile_time_ns_before)
        (Base.cumulative_compile_time_ns_before, Base.cumulative_compile_time_ns_after)
    elseif VERSION >= v"1.6.0-DEV.1088"
        (Base.cumulative_compile_time_ns, Base.cumulative_compile_time_ns)
    else
        (() -> UInt64(0), () -> UInt64(0))
    end
end

testset_beginend_call = begin
    if VERSION >= v"1.8.0-DEV.809"
        Test.testset_beginend_call
    else
        Test.testset_beginend
    end
end

trigger_test_failure_break = begin
    if VERSION >= v"1.9.0-DEV.228"
        Test.trigger_test_failure_break
    else
        () -> nothing
    end
end

struct FinishedWithErrors <: Exception
end

function Base.showerror(io::IO, ex::FinishedWithErrors, bt; backtrace=true)
    printstyled(io, "Test run finished with errors.", color=:red, bold=true)
end

function slash_to_path_separator(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, "/" => sep)
end

function path_separator_to_slash(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, sep => "/")
end

function get_all_files(dir::String, skip::Vector{String}, targets::Vector{String})
    filters = []
    start_idx = 1
    if !isempty(targets)
        let
            walkdir_list = walkdir(dir)
            (root, dirs, files) = first(walkdir_list)
            dir_and_files = vcat(dirs, files)
            for arg in targets
                if occursin('=', arg)
                    name, val = split(arg, '=')
                    if name == "start"
                        start_idx = parse(Int, val)
                    end
                else
                    filterpath = path_separator_to_slash(arg)
                    if filterpath == "."
                    elseif startswith(filterpath, "./")
                        push!(filters, filterpath[3:end])
                    else
                        push!(filters, filterpath)
                    end
                end
            end
        end
    end
    all_files = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        for filename in files
            !endswith(filename, ".jl") && continue
            root == dir && "runtests.jl" == filename && continue
            filepath = path_separator_to_slash(relpath(normpath(root, filename), dir))
            any(x -> startswith(filepath, x), path_separator_to_slash.(skip)) && continue
            !isempty(filters) && !any(filterpath -> startswith(filepath, filterpath), filters) && continue
            push!(all_files, filepath)
        end
    end
    (all_files, start_idx)
end

"""
    runtests(dir::String ;
             skip::Union{Vector{Any},Vector{String}} = String[],
             node1::Union{Vector{Any},Vector{String}} = [],
             targets::Vector{String} = ARGS,
             enable_distributed::Bool = true,
             stop_on_failure::Bool = false,
             context::Union{Nothing,Module} = nothing,
             verbose::Bool = true)

run the test files from the specific directory.

* `dir`: the root directory to traverse.
* `skip`: files or directories to skip.
* `node1`: run on node 1 during for the distributed tests.
* `targets`: filter targets and start. default is `ARGS`.
* `enable_distributed`: option for distributed.
* `stop_on_failure`: stop on the failure or error.
* `context`: module that to be used in `Base.include`. `nothing` means to be safe that using anonymous module for every test file.
* `verbose`: print details of test execution
"""
function runtests(dir::String ;
                  skip::Union{Vector{Any},Vector{String}} = String[],
                  node1::Union{Vector{Any},Vector{String}} = [],
                  targets::Vector{String} = ARGS,
                  enable_distributed::Bool = true,
                  stop_on_failure::Bool = false,
                  context::Union{Nothing,Module} = nothing,
                  verbose::Bool = true)
    (all_tests, start_idx) = get_all_files(dir, Vector{String}(skip), targets)
    env_jive_procs = get(ENV, "JIVE_PROCS", "") # "" "auto" "0" "1" "2" "3" ...
    if ("0" == env_jive_procs) || !enable_distributed
        normal_run(dir, all_tests, start_idx, stop_on_failure, context, verbose)
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
            distributed_run(dir, all_tests, start_idx, path_separator_to_slash.(node1), stop_on_failure, context, verbose)
        else
            normal_run(dir, all_tests, start_idx, stop_on_failure, context, verbose)
        end
    end
end

function include_test_file(context::Union{Nothing,Module}, filepath::String)
    if isnothing(context)
        m = Module()
        # https://github.com/JuliaLang/julia/issues/40189#issuecomment-871250226
        Core.eval(m, quote
            eval(x) = Core.eval($m, x)
            include(x) = Base.include($m, x)
        end)
        Base.include(m, filepath)
    else
        Base.include(context, filepath)
    end
end

function normal_run(dir::String, tests::Vector{String}, start_idx::Int, stop_on_failure::Bool, context::Union{Nothing,Module}, verbose::Bool)
    io = IOContext(Core.stdout, :color => have_color())
    total_compile_time = UInt64(0)
    total_elapsed_time = UInt64(0)
    total_anynonpass = false
    n_passes = 0
    n_fails = 0
    n_errors = 0
    n_broken = 0
    for (idx, subpath) in enumerate(tests)
        num_tests = length(tests)
        numbering = string(idx, /, num_tests)
        if idx < start_idx
            step = Step(io, numbering, subpath, " --")
            jive_getting_on_the_floor(step, verbose)
            continue
        end
        step = Step(io, numbering, subpath, "")
        jive_getting_on_the_floor(step, verbose)
        filepath = normpath(dir, slash_to_path_separator(subpath))
        ts = jive_lets_dance(step, stop_on_failure, context, filepath, verbose)
        total_compile_time += ts.compile_time
        total_elapsed_time += ts.elapsed_time
        if !total_anynonpass && ts.anynonpass
            total_anynonpass = true
        end
        tc = jive_get_test_counts(ts)
        n_passes += tc.passes
        n_fails += tc.fails
        n_errors += tc.errors
        n_broken += tc.broken
        stop_on_failure && ts.anynonpass && break
    end
    verbose && jive_report(io, total_compile_time, total_elapsed_time, total_anynonpass, n_passes, n_fails, n_errors, n_broken)
end

function jive_getting_on_the_floor(step::Step, verbose::Bool)
    if verbose
        io = step.io
        printstyled(io, step.numbering, color=:underline)
        print(io, ' ', step.subpath)
        !isempty(step.msg) && print(io, ' ', step.msg)
        println(io)
    end
end

function jive_lets_dance(step::Step, stop_on_failure::Bool, context::Union{Nothing,Module}, filepath::String, verbose::Bool)
    @testset_since_a23aa79f1a JiveTestSet "$(basename(filepath))" verbose=verbose step=step stop_on_failure=stop_on_failure context=context filepath=filepath include_test_file(context, filepath)
end

function jive_get_test_counts(ts::JiveTestSet)
    passes, fails, errors, broken = ts.n_passed, 0, 0, 0
    c_passes, c_fails, c_errors, c_broken = 0, 0, 0, 0
    skipped, c_skipped = 0, 0
    for t in ts.results
        isa(t, Fail)   && (fails  += 1)
        isa(t, Error)  && (errors += 1)
        if isa(t, Broken)
            if t.test_type === :skipped
                skipped += 1
            else
                broken += 1
            end
        end
        if isa(t, JiveTestSet)
            tc = get_test_counts(t)
            c_passes  += tc.passes  + tc.c_passes
            c_fails   += tc.fails   + tc.c_fails
            c_errors  += tc.errors  + tc.c_errors
            c_broken  += tc.broken  + tc.c_broken
            c_skipped += tc.skipped + tc.c_skipped
        end
    end
    return (; passes=passes, fails=fails, errors=errors, broken=broken, c_passes=c_passes, c_fails=c_fails, c_errors=c_errors, c_broken=c_broken, skipped=skipped, c_skipped=c_skipped)
end

function jive_print_counts(io::IO, compile_elapsedtime::UInt64, elapsedtime::UInt64, passes, fails, errors, broken, skipped)
    printed = false
    if passes > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Pass:", " "; bold=true, color=:green)
        printstyled(io, passes, color=:green)
        printed = true
    end

    if fails > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Fail:", " "; bold=true, color=Base.error_color())
        printstyled(io, fails, color=Base.error_color())
        printed = true
    end

    if errors > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Error:", " "; bold=true, color=Base.error_color())
        printstyled(io, errors, color=Base.error_color())
        printed = true
    end

    if broken > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Broken:", " "; bold=true, color=Base.warn_color())
        printstyled(io, broken, color=Base.warn_color())
        printed = true
    end

    if skipped > 0
        print(io, repeat(' ', 4))
        printstyled(io, "Skip:", " "; bold=true, color=Base.warn_color())
        printstyled(io, skipped, color=Base.warn_color())
        printed = true
    end

    printed && print_elapsed_times(io, compile_elapsedtime, elapsedtime)
end

function jive_report(io::IO, total_compile_time::UInt64, total_elapsed_time::UInt64, total_anynonpass::Bool, n_passes::Int, n_fails::Int, n_errors::Int, n_broken::Int)
    if total_anynonpass || n_fails > 0 || n_errors > 0
        printstyled(io, "❗️  ", color=:red)
        print(io, "Test run finished with ")
        if n_fails > 0
            print(io, n_fails, " test failure")
            print(io, n_fails > 1 ? "s" : "")
        end
        if n_fails > 0 && n_errors > 0
            print(io, ", ")
        end
        if n_errors > 0
            print(io, n_errors, " error")
            print(io, n_errors > 1 ? "s" : "")
        end
        print(io, ".")
        print_elapsed_times(io, total_compile_time, total_elapsed_time)
        throw(FinishedWithErrors())
    elseif n_passes > 0
        printstyled(io, "✅  ", color=:green)
        print(io, "All ")
        printstyled(io, n_passes, color=:green)
        print(io, " ")
        print(io, n_passes == 1 ? "test has" : "tests have")
        print(io, " been completed.")
        print_elapsed_times(io, total_compile_time, total_elapsed_time)
    end
end

function print_elapsed_times(io::IO, compile_elapsedtime::UInt64, elapsedtime::UInt64)
    print(io, repeat(' ', 2), "(")
    if compile_elapsedtime > 0
        Printf.@printf(io, "compile: %.2f, elapsed: ", compile_elapsedtime / 1e9)
    end
    Printf.@printf(io, "%.2f seconds", elapsedtime / 1e9)
    println(io, ")")
end

# module Jive
