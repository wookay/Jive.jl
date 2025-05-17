# module Jive

"""
    Skipped

Skipped expressions are in `Skipped.expressions`
"""
module Skipped
expressions = []
end # Jive.Skipped

is_enabled_jive_skip_macro() = get(ENV, "JIVE_ENABLE_SKIP_MACRO", "1") == "1"

"""
    @skip

skip the expression.
"""
macro skip(expr::Expr)
    if is_enabled_jive_skip_macro()
        typ = expr.head
        if typ in (:module, :struct)
            name = expr.args[2]
            push!(Skipped.expressions, typ=>name)
        elseif typ in (:function, :macro)
            fexpr = expr.args[1]
            push!(Skipped.expressions, typ=>first(fexpr.args))
        elseif typ === :call
            push!(Skipped.expressions, typ=>first(expr.args))
        else
            push!(Skipped.expressions, typ)
        end
        nothing
    else
        esc(expr)
    end
end

macro skip(node::QuoteNode)
    if is_enabled_jive_skip_macro()
        push!(Skipped.expressions, node.value)
        nothing
    else
        esc(node)
    end
end

macro skip(sym::Symbol)
    if is_enabled_jive_skip_macro()
        if sym === :nothing
            push!(Skipped.expressions, nothing)
        else
            push!(Skipped.expressions, sym)
        end
        nothing
    else
        esc(sym)
    end
end

macro skip(val::Any)
    if is_enabled_jive_skip_macro()
        push!(Skipped.expressions, val)
        nothing
    else
        esc(val)
    end
end

# module Jive
