module test2

using Test
using Example

@test Example.f() == 42

end
