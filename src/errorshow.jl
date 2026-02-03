# module Jive

if VERSION >= v"1.11"

# override this function if you want to
# Jive.showable_stackframe(frame::Base.StackTraces.StackFrame)::Bool
function showable_stackframe(frame)::Bool
    HIDE_STACKFRAME_IN_MODULES = Set([@__MODULE__])
    if Base.parentmodule(frame) in HIDE_STACKFRAME_IN_MODULES
        return false
    elseif frame.func === Symbol("macro expansion")
        target_macro_expansions::Set{String} = Set([
            "Jive/src/compat.jl",
            "Jive/ext/TestExt.jl",
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
using Base: InterpreterIP, BIG_STACKTRACE_SIZE, process_backtrace, show_reduced_backtrace,
            show_full_backtrace, stacktrace_linebreaks, update_stackframes_callback
using Base.StackTraces: StackFrame
import Base: show_backtrace
# from julia/base/errorshow.jl
# function show_backtrace(io::IO, t::Vector; prefix=nothing)
function show_backtrace(io::IO, t::Vector{StackFrame}; prefix=nothing)
    _show_backtrace(io, t; prefix)
end
function show_backtrace(io::IO, t::Vector{Union{Ptr{Nothing}, InterpreterIP}}; prefix=nothing)
    _show_backtrace(io, t; prefix)
end
function _show_backtrace(io::IO, t::Vector; prefix=nothing)
    if haskey(io, :last_shown_line_infos)
        empty!(io[:last_shown_line_infos])
    end

    # t is a pre-processed backtrace (ref #12856)
    if t isa Vector{Any} && (length(t) == 0 || t[1] isa Tuple{StackFrame,Int})
        filtered = t
    else
        filtered = filter(x -> showable_stackframe(x[1]), process_backtrace(t))
    end
    isempty(filtered) && return

    if length(filtered) == 1 && Base.StackTraces.is_top_level_frame(filtered[1][1])
        f = filtered[1][1]::StackFrame
        if f.line == 0 && f.file === :var""
            # don't show a single top-level frame with no location info
            return
        end
    end

    if length(filtered) > BIG_STACKTRACE_SIZE
        show_reduced_backtrace(IOContext(io, :backtrace => true), filtered; prefix)
        return
    else
        try invokelatest(update_stackframes_callback[], filtered) catch end
        # process_backtrace returns a Vector{Tuple{Frame, Int}}
        show_full_backtrace(io, filtered; print_linebreaks = stacktrace_linebreaks() #=, prefix =#)
    end
    nothing
end # function show_backtrace
    # elseif VERSION >= v"1.11"

end # if

# module Jive
