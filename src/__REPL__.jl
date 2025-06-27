# module Jive

using REPL

struct REPLError <: Exception
end

function isreplerror(ex::LoadError)
    if ex.error isa REPLError
        return true
    elseif ex.error isa LoadError
        return isreplerror(ex.error)
    else
        return false
    end
end

"""
    @__REPL__
"""
macro __REPL__()
    @eval function Base.showerror(io::IO, ex::LoadError, bt; backtrace=true)
        if isreplerror(ex)
            printstyled(io, "@__REPL__", color=:cyan)
            print(io, " at ", basename(ex.file), ":", ex.line)
        else
            print(io, "Error while loading expression starting at ", ex.file, ":", ex.line)
        end
    end
    quote
        if Base.JLOptions().isinteractive == 1 || isdefined(Base, :active_repl)
            throw(REPLError())
        else
            term = REPL.Terminals.TTYTerminal("dumb", stdin, stdout, stderr)
            repl = REPL.LineEditREPL(term, true)
            repl.history_file = true
            REPL.run_repl(repl)
        end
    end
end

# module Jive
