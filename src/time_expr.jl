# module Jive

# from julia/base/expr.jl  function remove_linenums!(@nospecialize ex)
#
# Remove all line-number metadata from expression-like object `ex`.
function remove_linenums_macrocall!(@nospecialize ex)
    if ex isa Expr
        if ex.head === :block || ex.head === :quote
            # remove line number expressions from metadata (not argument literal or inert) position
            filter!(ex.args) do x
                isa(x, Expr) && x.head === :line && return false
                isa(x, LineNumberNode) && return false
                return true
            end
        ### macrocall case
        elseif ex.head === :macrocall
            ex.args = map(ex.args) do subex
                isa(subex, LineNumberNode) ? nothing : subex
            end
        end
        for subex in ex.args
            subex isa Expr && remove_linenums_macrocall!(subex)
        end
    elseif ex isa CodeInfo
        ex.debuginfo = Core.DebugInfo(ex.debuginfo.def) # TODO: filter partially, but keep edges
    end
    return ex
end

using REPL

# from julia/base master/timing.jl  macro time(msg, ex)
macro time_expr(@nospecialize ex)
    quote
        local str_expr = string($(QuoteNode(remove_linenums_macrocall!(copy(ex)))))
        io = stdout
        printstyled(io, "@time"; color = :cyan)
        print(io, ' ')
        if VERSION >= v"1.12.0-DEV.901"
            print(io, REPL.JuliaSyntaxHighlighting.highlight(str_expr))
        else
            print(io, str_expr)
        end
        println(io)
        local ret = @timed $(esc(ex))
        if VERSION >= v"1.11.0-DEV.1459"
            Base.time_print(io, ret.time*1e9, ret.gcstats.allocd, ret.gcstats.total_time, Base.gc_alloc_count(ret.gcstats), ret.lock_conflicts, ret.compile_time*1e9, ret.recompile_time*1e9, true)
        elseif VERSION >= v"1.10.0-DEV.1399"
            Base.time_print(io, ret.time*1e9, ret.gcstats.allocd, ret.gcstats.total_time, Base.gc_alloc_count(ret.gcstats))
            println(io)
        else
            Base.time_print(ret.time*1e9, ret.gcstats.allocd, ret.gcstats.total_time, Base.gc_alloc_count(ret.gcstats))
            println(io)
        end
        ret.value
    end
end

# module Jive
