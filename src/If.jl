# module Jive

quote
    """
        @if(condition, expr)

    evaluate the expr by the condition.
    """
    macro $(Symbol("if"))(condition, expr)
        return if_impl(__module__, condition, expr)
    end
end |> eval

"""
    @If(condition::Expr, expr::Expr)

evaluate the expr by the condition.
"""
macro If(condition, expr)
    return if_impl(__module__, condition, expr)
end

function if_impl(mod, condition::Bool, expr::Expr)
    if condition
        Base.eval(mod, expr)
    end
end

function if_impl(mod, condition::Expr, expr::Expr)
    if Base.eval(mod, condition)
        Base.eval(mod, expr)
    end
end

# module Jive
