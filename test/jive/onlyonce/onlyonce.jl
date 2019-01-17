module test_jive_onlyonce

using Test
using Jive
empty!(Jive.onlyonce_evaluated)


include("heavy.jl")
@test val == 0

include("heavy.jl")
@test val == 42

include("heavy.jl")
@test val == 42

end # module test_jive_onlyonce
