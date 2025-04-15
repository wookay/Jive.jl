module test_jive_delete

using Test
using Jive

f() = 42
Jive.delete(f)
@test_throws MethodError(f, (), Base.get_world_counter()) f()

f(::Int) = 42
Jive.delete(f, Tuple{Int})
@test_throws MethodError(f, (0,), Base.get_world_counter()) f(0)

f(::Int) = 42
@test_throws ArgumentError("Collection is empty, must contain exactly 1 element") Jive.delete(f)
@test_throws MethodError(f, (), Base.get_world_counter()) f()
@test f(0) == 42
Jive.delete(f, Tuple{Int})

f(::Int, ::String) = 42
f(::Int, ::Int) = 42
f(::Int, ::Any) = 42
@test_throws ArgumentError("Collection has multiple elements, must contain exactly 1 element") Jive.delete(f, Tuple{Int, Any})
Jive.delete(f, Tuple{Int, String})
@test_throws ArgumentError("Collection has multiple elements, must contain exactly 1 element") Jive.delete(f, Tuple{Int, Any})
Jive.delete(f, Tuple{Int, Int})
Jive.delete(f, Tuple{Int, Any})

end # module test_jive_delete
