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

ret = @useinside Main module C
val_in_C = 1
42
end

@test Main.val_in_C == 1
@test ret == 42

ret = @useinside A module D
val_in_D = 1
42
end

@test A.val_in_D == 1
@test ret == 42

end # module test_jive_useinside


module test_jive_useinside_isdefined

using Test
using ..test_jive_useinside

@test !isdefined(Main, :test_jive_useinside)
@test isdefined(test_jive_useinside, :A)
@test !isdefined(test_jive_useinside, :B)
@test !isdefined(Main, :C)
@test Main.val_in_C == 1

end # module test_jive_useinside_isdefined
