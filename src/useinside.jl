# module Jive

"""
    @useinside(expr::Expr)

use inside of the module.
"""
macro useinside(expr::Expr)
    quot = expr.args[3]
    for x in quot.args
        @eval(__module__, $x)
    end
end

# module Jive
