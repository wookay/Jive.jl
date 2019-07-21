module test_jive_onlyonce_evaluated

using Test
using Jive
empty!(Jive.onlyonce_evaluated)
empty!(Jive.onlyonce_called)


include(normpath(@__DIR__, "heavy.jl"))
@test val == 0

include(normpath(@__DIR__, "heavy.jl"))
@test val == 42

include(normpath(@__DIR__, "heavy.jl"))
@test val == 42

end # module test_jive_onlyonce_evaluated


module test_jive_onlyonce_called_block

using Test
using Jive
empty!(Jive.onlyonce_evaluated)
empty!(Jive.onlyonce_called)

function f(x)
    @onlyonce begin
        x += 2
    end
    x
end # function f(x)

@test f(1) == 3
@test f(1) == 1
@test f(1) == 1

end # module test_jive_onlyonce_called_block


module test_jive_onlyonce_called_call

using Test
using Jive
empty!(Jive.onlyonce_evaluated)
empty!(Jive.onlyonce_called)

function f(x)
    @onlyonce(x += 2)
    x
end # function f(x)

@test f(1) == 3
@test f(1) == 1
@test f(1) == 1

end # module test_jive_onlyonce_called_call
