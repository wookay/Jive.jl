# module Jive

struct EndError <: Exception
end

function isenderror(ex::LoadError)
    if ex.error isa EndError
        return true
    elseif ex.error isa LoadError
        return isenderror(ex.error)
    else
        return false
    end
end

"""
    @__END__

`throw(Jive.EndError())`
"""
macro __END__()
    @eval function Base.showerror(io::IO, ex::LoadError, bt; backtrace=true)
        if isenderror(ex)
            printstyled(io, "@__END__", color=:cyan)
            print(io, " at ", basename(ex.file), ":", ex.line)
        else
            print(io, "Error while loading expression starting at ", ex.file, ":", ex.line)
        end
    end
    throw(EndError())
end

# module Jive
