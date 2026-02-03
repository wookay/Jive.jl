# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl

using Printf: Printf

global jive_testset_filter = nothing # be used at
                                     #   `macro testset(name::String, rest_args...)` in compat.jl
                                     #   `runtests(dir::String ; ...)` in runtests.jl

struct CompileTiming
    compile::UInt64
    recompile::UInt64
    elapsed::UInt64
end

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

include("compat.jl") # jive_testset_filter (using global)
include("runtests_distributed_run.jl")
include("errorshow.jl")

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
end # function get_all_files

# build_testset_filter
build_testset_filter(::Nothing) = nothing
build_testset_filter(testset_filter::AbstractString) = ==(testset_filter)
build_testset_filter(testset_filter::Vector{<: AbstractString}) = in(testset_filter)
build_testset_filter(testset_filter::Regex) = (x::AbstractString) -> match(testset_filter, x) isa RegexMatch
build_testset_filter(testset_filter::Base.Callable) = testset_filter

function get_override_targets(dir::String, targets::Union{AbstractString, Vector{<: AbstractString}})::Vector{String}
    if !isempty(ARGS) && basename(dir) == "test"
        if isempty(PROGRAM_FILE) || basename(PROGRAM_FILE) == "runtests.jl"
            return ARGS
        end
    end
    if targets isa AbstractString
        return split(targets) #  (space) separated
    else
        return targets
    end
end # function get_override_targets

"""
    runtests(dir::String ;
             failfast::Bool = false,
             targets::Union{AbstractString, Vector{<: AbstractString}} = String[],
             skip::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
             filter_testset::Union{Nothing, AbstractString, Vector{<: AbstractString}, Regex, Base.Callable} = nothing,
             into::Union{Nothing, Module} = nothing,
             enable_distributed::Bool = true,
             node1::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
             verbose::Bool = true)::Total

run the test files from the specific directory.

* `dir`: the root directory to traverse.
* `failfast`: aborting on the first failure. be overridden when the `ENV` variable `JULIA_TEST_FAILFAST` has set.
* `targets`: filter targets and start. ` `(space) separated `String` or a `Vector{String}`. be overridden when `ARGS` are not empty.
* `skip`: files or directories to skip. be overridden when the `ENV` variable `JIVE_SKIP` has set. `,`(comma) separated.
* `testset_filter`: filter testset. default is `nothing`.
* `into`: a module that to be used in `Base.include`. `nothing` means to be safe that using anonymous module for every test file.
* `enable_distributed`: option for distributed. be overridden when the `ENV` variable `JIVE_PROCS` has set.
* `node1`: run on node 1 during for the distributed tests.
* `verbose`: print details of test execution
"""
function runtests(dir::String ;
                  failfast::Bool = false,
                  targets::Union{AbstractString, Vector{<: AbstractString}} = String[],
                  skip::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
                  testset_filter::Union{Nothing, AbstractString, Vector{<: AbstractString}, Regex, Base.Callable} = nothing,
                  into::Union{Nothing, Module} = nothing,
                  enable_distributed::Bool = true,
                  node1::Union{Vector{Any}, Vector{<: AbstractString}} = String[],
                  verbose::Bool = true)::Total

    # override_failfast
    override_failfast = global_fail_fast()

    # override_targets
    override_targets = get_override_targets(dir, targets)

    # override_skip
    override_skip = begin
        env_jive_skip = get(ENV, "JIVE_SKIP", "")  # ,(comma) separated
        if isempty(env_jive_skip)
            Vector{String}(skip)
        else
            Vector{String}(split(env_jive_skip, ","))
        end
    end

    global jive_testset_filter = build_testset_filter(testset_filter)
    (all_tests, start_idx) = get_all_files(dir, override_skip, override_targets)

    if enable_distributed && isdefined(@__MODULE__, :runtests_distributed_run)
        return runtests_distributed_run(dir, all_tests, start_idx, node1, into, verbose, override_failfast)
    else
        return normal_run(dir, all_tests, start_idx, into, verbose, override_failfast)
    end
end # function runtests

function include_test_file(into::Union{Nothing, Module}, filepath::String)
    if into === nothing
        m = Module()
        # https://github.com/JuliaLang/julia/issues/40189#issuecomment-871250226
        Base.eval(m, quote
            eval(x) = Base.eval(@__MODULE__, x)
            include(x) = Base.include(@__MODULE__, x)
        end)
        Base.include(m, filepath)
    else
        Base.include(into, filepath)
    end
end

function got_anynonpass(tc)::Bool
    any(!iszero, (tc.fails, tc.errors))
end

function normal_run(dir::String, tests::Vector{String}, start_idx::Int, into::Union{Nothing,Module}, verbose::Bool, failfast::Bool)::Total
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
        ts = DefaultTestSet(description)
        (compiled::CompileTiming, tc::TestCounts) = jive_lets_dance(io, verbose, ts, into, filepath)
        verbose && jive_print_counts(io, tc, compiled)
        accumulate!(total, tc, compiled)
        failfast && got_anynonpass(tc) && break
    end
    verbose && jive_report(io, total)
    return total
end # function normal_run

function accumulate!(total::Total, tc::TestCounts, compiled::CompileTiming)
    total.compile_time   += compiled.compile
    total.recompile_time += compiled.recompile
    total.elapsed_time   += compiled.elapsed

    total_pass   = tc.cumulative_passes + tc.passes
    total_fail   = tc.cumulative_fails  + tc.fails 
    total_error  = tc.cumulative_errors + tc.errors
    total_broken = tc.cumulative_broken + tc.broken

    total.n_passes += total_pass
    total.n_fails  += total_fail
    total.n_errors += total_error
    total.n_broken += total_broken
end # function accumulate!

function jive_getting_on_the_floor(io::IO, numbering::String, subpath::String, msg::String)::Nothing
    printstyled(io, numbering, color=:underline)
    print(io, ' ', subpath)
    !isempty(msg) && print(io, ' ', msg)
    println(io)
end

function jive_testset_description(numbering)::String
    numbering
end

if VERSION >= v"1.13.0-DEV.1044" # julia commit bb36851288
using .compat_ScopedValues: with, CURRENT_TESTSET, TESTSET_DEPTH
end # if
function jive_lets_dance(io::IO, verbose::Bool, ts::DefaultTestSet, into::Union{Nothing, Module}, filepath::String)::Tuple{CompileTiming,TestCounts}
    elapsed_time_start = time_ns()
    verbose && _print_testset_verbose(:enter, ts)
    cumulative_compile_timing(true)
    (compile_time, recompile_time) = cumulative_compile_time_ns()
    compile_time_start   = compile_time
    recompile_time_start = recompile_time
    elapsed_time_start   = elapsed_time_start
    if VERSION >= v"1.13.0-DEV.1044" # julia commit bb36851288
        @noinline do_include_test_file() = include_test_file(into, filepath)
        with(do_include_test_file, CURRENT_TESTSET => ts, TESTSET_DEPTH => get_testset_depth() + 1)
        tc = get_test_counts(ts)
    else
        compat_push_testset(ts)
        include_test_file(into, filepath)
        compat_pop_testset()
        tc = get_test_counts(ts)
    end
    cumulative_compile_timing(false)
    (compile_time, recompile_time) = cumulative_compile_time_ns()
    compile_time   = compile_time - compile_time_start
    recompile_time = recompile_time - recompile_time_start
    elapsed_time   = time_ns() - elapsed_time_start
    verbose && _print_testset_verbose(:exit, ts)
    (CompileTiming(compile_time, recompile_time, elapsed_time), tc)
end # function jive_lets_dance

function jive_print_counts(io::IO, tc::TestCounts, compiled::CompileTiming)
    passes = tc.cumulative_passes + tc.passes
    fails  = tc.cumulative_fails  + tc.fails
    errors = tc.cumulative_errors + tc.errors
    broken = tc.cumulative_broken + tc.broken

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

    printed && print_elapsed_times(io, compiled.compile, compiled.recompile, compiled.elapsed)
end # function jive_print_counts

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
end # function print_elapsed_times

function jive_report(io::IO, total::Total)
    # total = total_pass + total_fail + total_error + total_broken
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
end # function jive_report

# module Jive
