# module Jive

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: TESTSET_PRINT_ENABLE, Pass, Broken, Error, Fail, AbstractTestSet, TestSetException, _check_testset, push_testset, pop_testset, get_testset_depth, get_testset, scrub_backtrace
import .Test: record, finish, filter_errors 

struct Step
    io
    numbering::String
    subpath::String
    msg::Union{String,Expr}
end

mutable struct JiveTestSet <: AbstractTestSet
    step::Union{Nothing,Step}
    context::Union{Nothing,Module}
    filepath::Union{Nothing,String}
    compile_time_start::UInt64
    elapsed_time_start::UInt64
    compile_time::UInt64
    elapsed_time::UInt64
    stop_on_failure::Bool
    description::String
    results::Vector{Any}
    n_passed::Int
    anynonpass::Bool
    verbose::Bool
    showtiming::Bool
    time_start::Float64
    time_end::Union{Float64,Nothing}
end
function JiveTestSet(desc::String; verbose::Bool = false, showtiming::Bool = true,
                                   step::Union{Nothing,Step} = nothing, context::Union{Nothing,Module} = nothing, filepath::Union{Nothing,String} = nothing, stop_on_failure::Bool = true)
    JiveTestSet(step, context, filepath, cumulative_compile_time_ns_before(), time_ns(), Int64(0), UInt64(0), stop_on_failure, desc, [], 0, false, verbose, showtiming, time(), nothing)
end

# Test.@testset  1.8.0-DEV.809
macro testset_since_a23aa79f1a(args...)
    isempty(args) && error("No arguments to @testset")

    tests = args[end]

    # Determine if a single block or for-loop style
    if !isa(tests,Expr) || (tests.head !== :for && tests.head !== :block && tests.head != :call)

        error("Expected function call, begin/end block or for loop as argument to @testset")
    end

    if tests.head === :for
        return testset_forloop(args, tests, __source__)
    else
        return testset_beginend_call(args, tests, __source__)
    end
end

function record(ts::JiveTestSet, t::Test.Pass)
    ts.n_passed += 1
    t
end

function record(ts::JiveTestSet, t::Test.Broken)
    push!(ts.results, t)
    t
end

function record(ts::JiveTestSet, t::Union{Fail, Error})
    if TESTSET_PRINT_ENABLE[]
        print(ts.description, ": ")
        # don't print for interrupted tests
        if !(t isa Error) || t.test_type !== :test_interrupted
            print(t)
            if !isa(t, Error) # if not gets printed in the show method
                Base.show_backtrace(stdout, scrub_backtrace(backtrace()))
            end
            println()
        end
    end
    push!(ts.results, t)
    return t
end

record(ts::JiveTestSet, t::AbstractTestSet) = push!(ts.results, t)

function finish(ts::JiveTestSet)
    ts.compile_time = cumulative_compile_time_ns_after() - ts.compile_time_start
    ts.elapsed_time = time_ns() - ts.elapsed_time_start
    tc = jive_get_test_counts(ts)
    ts.anynonpass = (tc.fails + tc.errors + tc.c_fails + tc.c_errors > 0)
    io = ts.step === nothing ? Core.stdout : ts.step.io
    ts.verbose && jive_print_counts(io, ts.compile_time, ts.elapsed_time, tc.passes, tc.fails, tc.errors, tc.broken, tc.skipped)
    total_pass   = tc.passes + tc.c_passes
    total_fail   = tc.fails  + tc.c_fails
    total_error  = tc.errors + tc.c_errors
    total_broken = tc.broken + tc.c_broken
    total        = total_pass + total_fail + total_error + total_broken

    # Finally throw an error as we are the outermost test set
    if ts.stop_on_failure && total != total_pass + total_broken
        # Get all the error/failures and bring them along for the ride
        efs = filter_errors(ts)
        throw(TestSetException(total_pass, total_fail, total_error, total_broken, efs))
    end

    # return the testset so it is returned from the @testset macro
    ts
end

function filter_errors(ts::JiveTestSet)
    efs = []
    for t in ts.results
        if isa(t, JiveTestSet)
            append!(efs, filter_errors(t))
        elseif isa(t, Union{Fail, Error})
            append!(efs, [t])
        end
    end
    efs
end

# module Jive
