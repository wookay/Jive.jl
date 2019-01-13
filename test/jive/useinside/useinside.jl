module test_jive_useinside

using Test
using Jive

module A
val1 = 1
end

@useinside module B
val2 = 1
end

@test val2 == 1

end # module test_jive_useinside


module test_jive_useinside_isdefined

using Test
using ..test_jive_useinside

@test isdefined(Main, :test_jive_useinside)
@test isdefined(test_jive_useinside, :A)
@test !isdefined(test_jive_useinside, :B)

end # module test_jive_useinside_isdefined
