# module Jive

macro If(condition::Bool, expr::Expr)
    if condition
        Base.eval(__module__, expr)
    end
end

macro If(condition::Expr, expr::Expr)
    if Base.eval(__module__, condition)
        Base.eval(__module__, expr)
    end
end

# module Jive
