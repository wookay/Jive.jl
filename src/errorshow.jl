# module Jive

if VERSION >= v"1.11"
HIDE_STACKFRAME_IN_MODULES #= ::Set{Module} =# = Set([(@__MODULE__)])

# override this function if you want to
# Jive.showable_stackframe(frame::Base.StackTraces.StackFrame)::Bool
function showable_stackframe(frame)::Bool
    if Base.parentmodule(frame) in HIDE_STACKFRAME_IN_MODULES
        return false
    elseif frame.func === Symbol("macro expansion")
        target_macro_expansions::Set{String} = Set([
            "Jive/src/runtests.jl",
            "Jive/src/compat.jl",
            "Test/src/Test.jl",
        ])
        frame_file = String(frame.file)
        for suffix in target_macro_expansions
            endswith(frame_file, suffix) && return false
        end
    # elseif frame.func === :include && frame.file === Symbol("./Base.jl")
    #     return false
    end
    return true
end # function showable_stackframe

end # if VERSION >= v"1.11"


if VERSION >= v"1.13.0-DEV.927" # julia commit 21d15ede0729a810458e2045f224e2e8a7db92e8
using Base: STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS
import Base: show_processed_backtrace
# from julia/base/errorshow.jl
# function show_processed_backtrace(io::IO, trace::Vector, num_frames::Int, repeated_cycles::Vector{NTuple{3, Int}}, max_nested_cycles::Int; print_linebreaks::Bool, prefix = nothing)
function show_processed_backtrace(io::IOContext, trace::Vector, num_frames::Int, repeated_cycles::Vector{NTuple{3, Int}}, max_nested_cycles::Int; print_linebreaks::Bool, prefix = nothing)
    println(io)
    prefix === nothing || print(io, prefix)
    println(io, "Stacktrace:")

    ndigits_max = ndigits(num_frames)

    push!(repeated_cycles, (0,0,0)) # repeated_cycles is never empty

    frame_counter = 1
    current_cycles = NTuple{4, Int}[] # adding a value to track amount to advance frame_counter when cycle is closed

    for i in eachindex(trace)
        (frame, n) = trace[i]
        if !showable_stackframe(frame)
            frame_counter += 1
            continue
        end

        ncycle_starts = 0
        while repeated_cycles[1][1] == i
            cycle = popfirst!(repeated_cycles)
            push!(current_cycles, (cycle..., cycle[2] * (cycle[3] - 1)))
            ncycle_starts += 1
        end
        if n > 1
            push!(current_cycles, (i, 1, n, n - 1))
            ncycle_starts += 1
        end
        nactive_cycles = length(current_cycles)

        Base.print_stackframe(io, frame_counter, frame, ndigits_max, max_nested_cycles, nactive_cycles, ncycle_starts, STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS; prefix)

        frame_counter, nactive_cycles = Base._backtrace_print_repetition_closings!(io, i, current_cycles, frame_counter, max_nested_cycles, nactive_cycles, ndigits_max; prefix)
        frame_counter += 1

        if i < length(trace)
            println(io)
            print_linebreaks && println(io)
        end
    end
end # function show_processed_backtrace
    # if VERSION >= v"1.13.0-DEV.927"

elseif VERSION >= v"1.11"
using Base: STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS
import Base: show_full_backtrace
# from julia/base/errorshow.jl
# function show_full_backtrace(io::IO, trace::Vector; print_linebreaks::Bool, prefix=nothing)
function show_full_backtrace(io::IOContext, trace::Vector; print_linebreaks::Bool, prefix=nothing)
    num_frames = length(trace)
    ndigits_max = ndigits(num_frames)

    println(io)
    prefix === nothing || print(io, prefix)
    println(io, "Stacktrace:")

    for (i, (frame, n)) in enumerate(trace)
        if !showable_stackframe(frame)
            continue
        end
        Base.print_stackframe(io, i, frame, n, ndigits_max, STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS)
        if i < num_frames
            println(io)
            print_linebreaks && println(io)
        end
    end
end # function show_full_backtrace
    # elseif VERSION >= v"1.11"

end # if

# module Jive
