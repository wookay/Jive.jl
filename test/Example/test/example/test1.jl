module test1

using Test
using Example

@test Example.f() == 42

end
