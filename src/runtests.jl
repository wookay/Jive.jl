# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl

using Test: Test, push_testset, pop_testset, get_testset_depth, get_testset
using Distributed: Distributed, nprocs, addprocs
using Printf: Printf

# compat
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

global jive_testset_filter = nothing

include("compat.jl")
include("runtests_testset.jl")
include("runtests_distributed_run.jl")

mutable struct Total
    compile_time::UInt64
    recompile_time::UInt64
    elapsed_time::UInt64
    n_passes::Int
    n_fails::Int
    n_errors::Int
    n_broken::Int
    n_skipped::Int
    function Total()
        new(UInt64(0), UInt64(0), UInt64(0), 0, 0, 0, 0, 0)
    end
end

struct FinishedWithErrorsException <: Exception
end

function Base.showerror(io::IO, ex::FinishedWithErrorsException, bt; backtrace=true)
    printstyled(io, "Test run finished with errors.", color=:red, bold=true)
end

@generated have_color() = :(2 != Base.JLOptions().color)

function slash_to_path_separator(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, "/" => sep)
end

function path_separator_to_slash(subpath::String)
    sep = Base.Filesystem.path_separator
    sep == "/" ? subpath : replace(subpath, sep => "/")
end

function get_all_files(dir::String, skip::Vector{String}, targets::Vector{String})
    filters = Vector{String}()
    start_idx = 1
    if !isempty(targets)
        for arg in targets
            if occursin('=', arg)
                name, val = split(arg, '=')
                if name == "start" && !isempty(val) && all(isdigit, val)
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
        end # for arg in targets
    end

    all_files = Vector{String}()
    function traverse_target(dir::String, filterpath::Union{Nothing, String})
        for (root, dirs, files) in walkdir(dir)
            for filename in files
                !endswith(filename, ".jl") && continue
                root == dir && "runtests.jl" == filename && continue
                filepath = path_separator_to_slash(relpath(normpath(root, filename), dir))
                any(x -> startswith(filepath, x), path_separator_to_slash.(skip)) && continue
                if filterpath === nothing
                    push!(all_files, filepath)
                else
                    startswith(filepath, filterpath) && push!(all_files, filepath)
                end
            end # for filename in files
        end # for (root, dirs, files) in walkdir(dir)
    end

    if isempty(filters)
        traverse_target(dir, nothing)
        all_unique_files = all_files
    else
        for filterpath in filters
            traverse_target(dir, filterpath)
        end
        all_unique_files = unique(all_files)
    end
    (all_unique_files, start_idx)
end

"""
    runtests(dir::String ;
             failfast::Bool = false,
             targets::Union{AbstractString, Vector{<: AbstractString}} = String[],
             skip::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
             testset::Union{Nothing, AbstractString, Vector{<: AbstractString}, Regex, Base.Callable} = nothing,
             context::Union{Nothing, Module} = nothing,
             enable_distributed::Bool = true,
             node1::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
             verbose::Bool = true)::Total

run the test files from the specific directory.

* `dir`: the root directory to traverse.
* `failfast`: aborting on the first failure. be overridden when the `ENV` variable `JULIA_TEST_FAILFAST` has set.
* `targets`: filter targets and start. ` `(space) separated `String` or a `Vector{String}`. be overridden when `ARGS` are not empty.
* `skip`: files or directories to skip. be overridden when the `ENV` variable `JIVE_SKIP` has set. `,`(comma) separated.
* `testset`: filter testset. default is `nothing`.
* `context`: module that to be used in `Base.include`. `nothing` means to be safe that using anonymous module for every test file.
* `enable_distributed`: option for distributed. be overridden when the `ENV` variable `JIVE_PROCS` has set.
* `node1`: run on node 1 during for the distributed tests.
* `verbose`: print details of test execution
"""
function runtests(dir::String ;
                  failfast::Bool = false,
                  targets::Union{AbstractString, Vector{<: AbstractString}} = String[],
                  skip::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
                  testset::Union{Nothing, AbstractString, Vector{<: AbstractString}, Regex, Base.Callable} = nothing,
                  context::Union{Nothing, Module} = nothing,
                  enable_distributed::Bool = true,
                  node1::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
                  verbose::Bool = true)::Total

    # override_failfast
    FAIL_FAST[] = override_failfast = compat_get_bool_env("JULIA_TEST_FAILFAST", failfast)

    # override_targets
    override_targets = begin
         if !isempty(ARGS) && basename(dir) == "test" && basename(PROGRAM_FILE) == "runtests.jl"
             ARGS
        elseif targets isa AbstractString
            Vector{String}(split(targets)) #  (space) separated
        else
            Vector{String}(targets)
        end
    end

    # override_skip
    override_skip = begin
        env_jive_skip = get(ENV, "JIVE_SKIP", "")  # ,(comma) separated
        if isempty(env_jive_skip)
            Vector{String}(skip)
        else
            Vector{String}(split(env_jive_skip, ","))
        end
    end

    global jive_testset_filter = build_testset_filter(testset)
    (all_tests, start_idx) = get_all_files(dir, override_skip, override_targets)

    if enable_distributed && isdefined(@__MODULE__, :runtests_distributed_run)
        return runtests_distributed_run(dir, all_tests, start_idx, node1, context, verbose, override_failfast)
    else
        return normal_run(dir, all_tests, start_idx, context, verbose, override_failfast)
    end
end

build_testset_filter(::Nothing) = nothing
build_testset_filter(testset::AbstractString) = ==(testset)
build_testset_filter(testset::Vector{<: AbstractString}) = in(testset)
build_testset_filter(testset::Regex) = (x::AbstractString) -> match(testset, x) isa RegexMatch
build_testset_filter(testset::Base.Callable) = testset

function include_test_file(context::Union{Nothing, Module}, filepath::String)
    if context === nothing
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

function got_anynonpass(tc)::Bool
    any(!iszero, (tc.fails, tc.c_fails, tc.errors, tc.c_errors))
end

function normal_run(dir::String, tests::Vector{String}, start_idx::Int, context::Union{Nothing,Module}, verbose::Bool, failfast::Bool)::Total
    io = IOContext(Core.stdout, :color => have_color())
    total = Total()
    for (idx, subpath) in enumerate(tests)
        num_tests = length(tests)
        numbering = string(idx, /, num_tests)
        if idx < start_idx
            verbose && jive_getting_on_the_floor(io, numbering, subpath, " --")
            continue
        end
        verbose && jive_getting_on_the_floor(io, numbering, subpath, "")
        filepath = normpath(dir, slash_to_path_separator(subpath))
        description = jive_testset_description(numbering)
        ts = JiveTestSet(description)
        try
            jive_lets_dance(io, verbose, ts, context, filepath)
        catch _e
            if Test.is_failfast_error(_e)
                failfast = true
            else
                rethrow(_e)
            end
        end # try
        tc = jive_accumulate_testset_data(io, verbose, total, ts)
        failfast && got_anynonpass(tc) && break
    end
    verbose && jive_report(io, total)
    return total
end

function jive_accumulate_testset_data(io::IO, verbose::Bool, total::Total, ts::JiveTestSet)
    total.compile_time   += ts.compile_time
    total.recompile_time += ts.recompile_time
    total.elapsed_time   += ts.elapsed_time
    tc = jive_get_test_counts(ts)
    verbose && jive_print_counts(io, ts, tc)
    total.n_passes  += tc.passes  + tc.c_passes
    total.n_fails   += tc.fails   + tc.c_fails
    total.n_errors  += tc.errors  + tc.c_errors
    total.n_broken  += tc.broken  + tc.c_broken
    total.n_skipped += tc.skipped + tc.c_skipped
    tc
end

function jive_testset_description(numbering)::String
    numbering
end

function jive_getting_on_the_floor(io::IO, numbering::String, subpath::String, msg::String)::Nothing
    printstyled(io, numbering, color=:underline)
    print(io, ' ', subpath)
    !isempty(msg) && print(io, ' ', msg)
    println(io)
end

function jive_lets_dance(io::IO, verbose::Bool, ts::JiveTestSet, context::Union{Nothing, Module}, filepath::String)
    push_testset(ts)
    jive_start!(ts)
    include_test_file(context, filepath)
    jive_finish!(io, verbose, :jive, ts)
    pop_testset()
end

function jive_start!(ts::JiveTestSet)
    elapsed_time_start = time_ns()
    cumulative_compile_timing(true)
    compile_time, recompile_time = cumulative_compile_time_ns()
    ts.compile_time_start   = compile_time
    ts.recompile_time_start = recompile_time
    ts.elapsed_time_start   = elapsed_time_start
end

function jive_finish!(io::IO, verbose::Bool, from::Symbol, ts::JiveTestSet)
    cumulative_compile_timing(false)
    compile_time, recompile_time = cumulative_compile_time_ns()
    ts.compile_time   = compile_time - ts.compile_time_start
    ts.recompile_time = recompile_time - ts.recompile_time_start
    ts.elapsed_time   = time_ns() - ts.elapsed_time_start

    if from === :test
        if get_testset_depth() != 0
            # Attach this test set to the parent test set
            parent_ts = get_testset()
            record(parent_ts, ts)
        end
    end

    ts
end

function print_elapsed_times(io::IO, compile_time::UInt64, recompile_time::UInt64, elapsed_time::UInt64)
    print(io, repeat(' ', 2), "(")
    if compile_time > 0
        Printf.@printf(io, "compile: %.2f, ", compile_time / 1e9)
        if recompile_time > 0
            Printf.@printf(io, "recompile: %.2f, ", recompile_time / 1e9)
        end
        Printf.@printf(io, "elapsed: ")
    end
    Printf.@printf(io, "%.2f seconds", elapsed_time / 1e9)
    println(io, ")")
end

function jive_get_test_counts(ts::JiveTestSet)
      passes,   fails,   errors,   broken,   skipped = ts.default.n_passed, 0, 0, 0, 0
    c_passes, c_fails, c_errors, c_broken, c_skipped = 0,                   0, 0, 0, 0
    for t in ts.default.results
        isa(t, Fail)   && (fails  += 1)
        isa(t, Error)  && (errors += 1)
        if isa(t, Test.Broken)
            if t.test_type === :skipped
                skipped += 1
            else
                broken += 1
            end
        end
        if isa(t, JiveTestSet)
            tc = jive_get_test_counts(t)
            c_passes  += tc.passes  + tc.c_passes
            c_fails   += tc.fails   + tc.c_fails
            c_errors  += tc.errors  + tc.c_errors
            c_broken  += tc.broken  + tc.c_broken
            c_skipped += tc.skipped + tc.c_skipped
        end
    end
    return (; passes=passes, fails=fails, errors=errors, broken=broken, c_passes=c_passes, c_fails=c_fails, c_errors=c_errors, c_broken=c_broken, skipped=skipped, c_skipped=c_skipped)
end

function jive_print_counts(io::IO, ts::JiveTestSet, tc)
    passes::Int  = tc.passes  + tc.c_passes
    fails::Int   = tc.fails   + tc.c_fails
    errors::Int  = tc.errors  + tc.c_errors
    broken::Int  = tc.broken  + tc.c_broken
    skipped::Int = tc.skipped + tc.c_skipped

    printed = false
    if passes > 0
        printstyled(io, "    Pass: "; bold=true, color=:green)
        printstyled(io, passes; color=:green)
        printed = true
    end

    if fails > 0
        printstyled(io, "    Fail: "; bold=true, color=Base.error_color())
        printstyled(io, fails; color=Base.error_color())
        printed = true
    end

    if errors > 0
        printstyled(io, "    Error: "; bold=true, color=Base.error_color())
        printstyled(io, errors; color=Base.error_color())
        printed = true
    end

    if broken > 0
        printstyled(io, "    Broken: "; bold=true, color=Base.warn_color())
        printstyled(io, broken; color=Base.warn_color())
        printed = true
    end

    if skipped > 0
        printstyled(io, "    Skip: "; bold=true, color=Base.warn_color())
        printstyled(io, skipped; color=Base.warn_color())
        printed = true
    end

    printed && print_elapsed_times(io, ts.compile_time, ts.recompile_time, ts.elapsed_time)
end

function jive_report(io::IO, total::Total)
    n_passes::Int, n_fails::Int, n_errors::Int, n_broken::Int, n_skipped::Int =
        total.n_passes, total.n_fails, total.n_errors, total.n_broken, total.n_skipped

    if n_fails > 0 || n_errors > 0
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
        print_elapsed_times(io, total.compile_time, total.recompile_time, total.elapsed_time)
        throw(FinishedWithErrorsException())
    elseif n_passes > 0
        printstyled(io, "✅  ", color=:green)
        print(io, "All ")
        printstyled(io, n_passes, color=:green)
        print(io, " ")
        print(io, n_passes == 1 ? "test has" : "tests have")
        print(io, " been completed.")
        print_elapsed_times(io, total.compile_time, total.recompile_time, total.elapsed_time)
    end
end

# module Jive
