module test_jive_onlyonce

using Test

include("heavy.jl")
@test val == 0

include("heavy.jl")
@test val == 42

include("heavy.jl")
@test val == 42

end # module test_jive_onlyonce
