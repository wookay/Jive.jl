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

# module Jive
