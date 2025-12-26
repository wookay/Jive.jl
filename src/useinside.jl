# module Jive

function _useinsde(mod::Module, expr::Expr)
    quot = last(expr.args)
    ret = nothing
    for x in quot.args
        ret = @eval(mod, $x)
    end
    ret
end

"""
    @useinside(expr::Expr)

use inside of the module.
"""
macro useinside(expr::Expr)
    _useinsde(__module__, expr)
end

"""
    @useinside(mod::Symbol, expr::Expr)

use inside of the module.
`mod` is the module to evaluate in.
"""
macro useinside(mod::Symbol, expr::Expr)
    m::Module = Base.eval(__module__, mod)
    _useinsde(m, expr)
end

# module Jive
