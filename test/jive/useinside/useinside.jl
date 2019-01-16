module test_jive_useinside

using Test
using Jive

module A
val_in_A = 1
end

ret = @useinside module B
val_in_B = 1
42
end

@test val_in_B == 1
@test ret == 42

end # module test_jive_useinside


module test_jive_useinside_isdefined

using Test
using ..test_jive_useinside

@test isdefined(Main, :test_jive_useinside)
@test isdefined(test_jive_useinside, :A)
@test !isdefined(test_jive_useinside, :B)

end # module test_jive_useinside_isdefined
