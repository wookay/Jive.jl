# module Jive

"""
    Jive.delete(@nospecialize(f), @nospecialize(types::Type{NTuple{N, T}}) = Tuple{}) where {N, T}

Make function `f` uncallable
"""
function delete(@nospecialize(f), @nospecialize(types::Type{NTuple{N, T}}) = Tuple{}) where {N, T}
    method = only(methods(f, types))
    Base.delete_method(method)
end

# module Jive
