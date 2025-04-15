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
@test_throws ArgumentError("Collection is empty, must contain exactly 1 element") Jive.delete(f, Tuple{})
@test_throws MethodError(f, (), Base.get_world_counter()) f()
@test f(0) == 42

end # module test_jive_delete
