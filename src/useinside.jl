# module Jive

"""
    @useinside(expr::Expr)

use inside of the module.
"""
macro useinside(expr::Expr)
    quot = expr.args[3]
    ret = nothing
    for x in quot.args
        ret = @eval(__module__, $x)
    end
    ret
end

# module Jive
