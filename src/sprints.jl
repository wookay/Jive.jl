# module Jive

"""
    sprint_plain(x)::String

get `Base.show` text/plain output of the `x`
"""
function sprint_plain(x)::String
    sprint(io -> show(io, MIME"text/plain"(), x))
end

"""
    sprint_colored(x)::String

get `Base.show` text/plain output of the `x` with color
"""
function sprint_colored(x)::String
    sprint(io -> show(io, MIME"text/plain"(), x); context = :color => true)
end

"""
    sprint_html(x)::String

get `Base.show` text/html output of the `x`
"""
function sprint_html(x)::String
    sprint(io -> show(io, MIME"text/html"(), x))
end


using IOCapture: IOCapture

macro sprint_plain(ex)
    if ex isa Expr && ex.head === :call
        quot = quote
            captured = $IOCapture.capture(; color = false) do
                $ex
            end
            captured.output::String
        end
        esc(quot)
    else
        quot = quote
            sprint_plain($ex)
        end
        esc(quot)
    end
end

macro sprint_colored(ex)
    if ex isa Expr && ex.head === :call
        quot = quote
            captured = $IOCapture.capture(; color = true) do
                $ex
            end
            captured.output::String
        end
        esc(quot)
    else
        quot = quote
            sprint_colored($ex)
        end
        esc(quot)
    end
end

# module Jive
