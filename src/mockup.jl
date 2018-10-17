# module Jive

module Mock
end # Jive.Mock

function using_symbols(modul::Module, name::Symbol, used::Vector{Symbol}, funcs::Vector{Symbol})
    filter(names(modul, all=true)) do sym
        if sym in used
            false
        elseif sym in funcs
            true
        else
            first(String(sym)) != '#' && !(sym in (name, :eval, :include)) && !(getfield(modul, sym) isa Function)
        end
    end
end

function diff_symbols(modul::Module, nofuncmodul::Module)
    modulnames = names(modul, all=true)
    nofuncnames = names(nofuncmodul, all=true)
    filter(setdiff(modulnames, nofuncnames)) do sym
        first(String(sym)) != '#' && (getfield(modul, sym) isa Function)
    end
end

function mockup_a_module(modul::Module, expr::Expr, used::Vector{Symbol}, funcs::Vector{Symbol})
    name = expr.args[2]
    body = expr.args[3]
    syms = using_symbols(modul, name, used, funcs)
    using_exprs = Vector{Expr}()
    for sym in syms
        ex = Expr(:using, Expr(:(:),
            Expr(:., :., :., :., name),
            Expr(:., sym)))
        push!(used, sym)
        push!(using_exprs, ex)
    end
    pushfirst!(body.args, using_exprs...)
    toplevel = Expr(:toplevel,
        Expr(:module, true, :Mock, Expr(:block, 
            Expr(:module, true, name, body)),
    ))
    toplevel
end

macro mockup(expr::Expr)
    name = expr.args[2]
    modul = getfield(__module__, name)
    local mockmodul
    local oldstderr = stderr
    local errread, errwrite, errstream
    try
        (errread, errwrite) = redirect_stderr()
        used = Vector{Symbol}()
        ex = mockup_a_module(modul, expr, used, Symbol[])
        nofuncmodul = getfield(__module__.eval(ex), name)
        funcs = diff_symbols(modul, nofuncmodul)
        mockex = mockup_a_module(modul, expr, used, funcs)
        # @info :mockex mockex
        mockmodul = getfield(__module__.eval(mockex), name)
        errstream = @async read(errread, String)
    finally
        redirect_stderr(oldstderr)
        close(errwrite)
    end
    errmsg = replace(fetch(errstream), "WARNING: replacing module Mock.\n" => "")
    isempty(errmsg) || println(stderr, errmsg)
    mockmodul
end

# module Jive
