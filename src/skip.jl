# module Jive

module Skipped
modules = []
end # Jive.Skipped

macro skip(expr::Expr)
    JIVE_SKIP = get(ENV, "JIVE_SKIP", "1") == "1"
    if JIVE_SKIP
        name = expr.args[2]
        push!(Skipped.modules, name)
        nothing
    else
        Base.eval(__module__, expr)
    end
end

# module Jive
