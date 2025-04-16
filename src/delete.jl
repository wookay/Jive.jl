# module Jive

"""
    Jive.delete(@nospecialize(f), @nospecialize(types::Type{T}) = Tuple{}) where T <: Tuple

Make function `f` uncallable.
same for `Base.delete_method(only(methods(f, types)))`
"""
function delete(@nospecialize(f), @nospecialize(types::Type{T}) = Tuple{}) where T <: Tuple
    method = only(methods(f, types))
    Base.delete_method(method)
end

# module Jive
