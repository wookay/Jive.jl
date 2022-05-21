# module Jive

# some code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: AbstractTestSet, DefaultTestSet

function compat_default_testset(args...; kwargs...)::DefaultTestSet
    if VERSION < v"1.9.0-DEV.623"
        ignore_keys = Vector{Symbol}()
        push!(ignore_keys, :failfast)
        if VERSION < v"1.6.0-DEV.1437"
            push!(ignore_keys, :verbose)
        end
        filtered_kwargs = filter(kv -> !(first(kv) in ignore_keys), kwargs)
        DefaultTestSet(args...; filtered_kwargs...)
    else
        DefaultTestSet(args...; kwargs...)
    end
end

mutable struct JiveTestSet <: AbstractTestSet
    compile_time_start::UInt64
    recompile_time_start::UInt64
    elapsed_time_start::UInt64
    compile_time::UInt64
    recompile_time::UInt64
    elapsed_time::UInt64
    default::DefaultTestSet
    function JiveTestSet(args...; kwargs...)
        new(UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), UInt64(0), compat_default_testset(args...; kwargs...))
    end
end

using .Test: TESTSET_PRINT_ENABLE, scrub_backtrace
import .Test: record, finish

# import .Test: record
function record(ts::JiveTestSet, t::Test.Pass)
    ts.default.n_passed += 1
    t
end

function record(ts::JiveTestSet, t::Test.Broken)
    push!(ts.default.results, t)
    t
end

function record(ts::JiveTestSet, t::Union{Test.Fail, Test.Error})
    if TESTSET_PRINT_ENABLE[]
        print(ts.default.description, ": ")
        # don't print for interrupted tests
        if !(t isa Test.Error) || t.test_type !== :test_interrupted
            print(t)
            if !isa(t, Test.Error) # if not gets printed in the show method
                Base.show_backtrace(stdout, scrub_backtrace(backtrace()))
            end
            println()
        end
    end
    push!(ts.default.results, t)
    return t
end

function record(ts::JiveTestSet, t::AbstractTestSet)
    push!(ts.default.results, t)
end

# import .Test: finish
function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end

# module Jive
