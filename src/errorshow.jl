# module Jive

using Base.StackTraces: StackFrame

function frame_called_from_jive(frame::StackFrame)::Bool
    if Base.parentmodule(frame) === (@__MODULE__)
        return true
    elseif Symbol("macro expansion") === frame.func
        frame_file = String(frame.file)
        if endswith(frame_file, "Jive/src/runtests.jl") || endswith(frame_file, "Jive/src/compat.jl")
            return true
        end
    end
    return false
end

if VERSION >= v"1.13.0-DEV.927" # julia commit 21d15ede0729a810458e2045f224e2e8a7db92e8
     # from julia/base/errorshow.jl
     # function print_stackframe(io, i, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolordict, modulecolorcycler; prefix = nothing)
     function _print_stackframe(io, i, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolordict, modulecolorcycler; prefix = nothing)
         m = Base.parentmodule(frame)
         modulecolor = if m !== nothing
             m = Base.parentmodule_before_main(m)
             get!(() -> popfirst!(modulecolorcycler), modulecolordict, m)
         else
             :default
         end
         Base.print_stackframe(io, i, frame, ndigits_max, max_nested_cycles, nactive_cycles, ncycle_starts, modulecolor; prefix)
     end # function _print_stackframe

    import Base: print_stackframe
    # from julia/base/errorshow.jl
    # function print_stackframe(io, i, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolordict, modulecolorcycler; prefix = nothing)
    function print_stackframe(io::IO, i::Int, frame::StackFrame, ndigits_max::Int, max_nested_cycles::Int, nactive_cycles::Int, ncycle_starts::Int, modulecolordict, modulecolorcycler; prefix = nothing)
        if !frame_called_from_jive(frame)
            _print_stackframe(io, i, frame, ndigits_max, max_nested_cycles, nactive_cycles, ncycle_starts, modulecolordict, modulecolorcycler; prefix)
        end
    end # function print_stackframe

elseif VERSION >= v"1.11"
    using Base: STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS
    import Base: show_full_backtrace
    # from julia/base/errorshow.jl
    # function show_full_backtrace(io::IO, trace::Vector; print_linebreaks::Bool, prefix=nothing)
    function show_full_backtrace(io::IOContext{IOBuffer}, trace::Vector; print_linebreaks::Bool, prefix=nothing)
        num_frames = length(trace)
        ndigits_max = ndigits(num_frames)

        println(io)
        prefix === nothing || print(io, prefix)
        println(io, "Stacktrace:")

        for (i, (frame, n)) in enumerate(trace)
            frame_called_from_jive(frame) && continue
            Base.print_stackframe(io, i, frame, n, ndigits_max, STACKTRACE_FIXEDCOLORS, STACKTRACE_MODULECOLORS)
            if i < num_frames
                println(io)
                print_linebreaks && println(io)
            end
        end
    end # function show_full_backtrace
end

# module Jive
