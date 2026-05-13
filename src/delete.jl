# module Jive

"""
    Jive.delete(@nospecialize(f), @nospecialize(t = ()))

Make function `f` uncallable.
same for `Base.delete_method(which(f, t))`
"""
function delete(@nospecialize(f), @nospecialize(t = ()))
    method = which(f, t)
    Base.delete_method(method)
end

# module Jive
