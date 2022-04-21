# module Jive

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: TESTSET_PRINT_ENABLE, Pass, Broken, Error, Fail, AbstractTestSet, TestSetException, _check_testset, push_testset, pop_testset, get_testset_depth, get_testset, scrub_backtrace
import .Test: record, finish, filter_errors 

struct Step
    io
    numbering::String
    subpath::String
    msg::Union{String,Expr}
    context::Union{Nothing,Module}
    filepath::Union{Nothing,String}
    verbose::Bool
end

mutable struct JiveTestSet <: AbstractTestSet
    description::String
    results::Vector{Any}
    n_passed::Int
    compile_time_start::UInt64
    recompile_time_start::UInt64
    elapsed_time_start::UInt64
    compile_time::UInt64
    recompile_time::UInt64
    elapsed_time::UInt64
    function JiveTestSet(description::String; verbose::Bool = false, showtiming::Bool = true)
        new(description, [], 0, UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0))
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

function record(ts::JiveTestSet, t::AbstractTestSet)
    push!(ts.results, t)
end

function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end

function jive_start!(ts::JiveTestSet)
    elapsed_time_start = time_ns()
    cumulative_compile_timing(true)
    compile_time, recompile_time = cumulative_compile_time_ns()
    ts.compile_time_start = compile_time
    ts.recompile_time_start = recompile_time
    ts.elapsed_time_start = elapsed_time_start
end

function jive_finish!(io, verbose::Bool, from::Symbol, ts::JiveTestSet)
    cumulative_compile_timing(false)
    compile_time, recompile_time = cumulative_compile_time_ns()
    ts.compile_time = compile_time - ts.compile_time_start
    ts.recompile_time = recompile_time - ts.recompile_time_start
    ts.elapsed_time = time_ns() - ts.elapsed_time_start

    if from === :test
        if get_testset_depth() != 0
            # Attach this test set to the parent test set
            parent_ts = get_testset()
            record(parent_ts, ts)
        end
    end

    ts
end

# module Jive
