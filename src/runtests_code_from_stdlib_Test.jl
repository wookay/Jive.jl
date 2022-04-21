# module Jive

# code from https://github.com/JuliaLang/julia/blob/master/stdlib/Test/src/Test.jl

using .Test: TESTSET_PRINT_ENABLE, AbstractTestSet, scrub_backtrace
import .Test: record, finish

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

# import .Test: record
function record(ts::JiveTestSet, t::Test.Pass)
    ts.n_passed += 1
    t
end

function record(ts::JiveTestSet, t::Test.Broken)
    push!(ts.results, t)
    t
end

function record(ts::JiveTestSet, t::Union{Test.Fail, Test.Error})
    if TESTSET_PRINT_ENABLE[]
        print(ts.description, ": ")
        # don't print for interrupted tests
        if !(t isa Test.Error) || t.test_type !== :test_interrupted
            print(t)
            if !isa(t, Test.Error) # if not gets printed in the show method
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

# import .Test: finish
function finish(ts::JiveTestSet)
    jive_finish!(Core.stdout, true, :test, ts)
end

# module Jive
