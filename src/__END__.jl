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
    throw(EndError())
end

# module Jive
