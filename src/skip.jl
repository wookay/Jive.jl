# module Jive

module Skipped
modules = []
functions = []
calls = []
end # Jive.Skipped

macro skip(expr::Expr)
    JIVE_SKIP = get(ENV, "JIVE_SKIP", "1") == "1"
    if JIVE_SKIP
        typ = expr.head
        if typ == :module
            name = expr.args[2]
            push!(Skipped.modules, name)
        elseif typ == :function
            fexpr = expr.args[1]
            push!(Skipped.functions, first(fexpr.args))
        elseif typ == :call
            push!(Skipped.calls, first(expr.args))
        end
        nothing
    else
        Base.eval(__module__, expr)
    end
end

# module Jive
