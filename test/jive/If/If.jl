module test_jive_If

using Jive # @If

@If true module A
f() = 1
end

@If false module B
f() = 1
end

using Test
@test isdefined(@__MODULE__, :A)
@test !isdefined(@__MODULE__, :B)
@test A.f() == 1

@if true module A_if
f() = 1
end

@if false module B_if
f() = 1
end

@test isdefined(@__MODULE__, :A)
@test !isdefined(@__MODULE__, :B)
@test A_if.f() == 1

end # module test_jive_If
