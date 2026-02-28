module test_jive_runtests_compat

using Test
using Jive

ts = @testset "empty" begin
end

# anynonpass
tc = Jive.get_test_counts(ts)
@test !(@inferred Jive.anynonpass(tc))

@test !(@inferred Jive.anynonpass(ts))


# compat_get_bool_env
withenv(
    "VAR1" => "nothing1",
    "VAR2" => "true",
    ) do
    @test Jive.compat_get_bool_env("VAR1", true) === nothing
    @test Jive.compat_get_bool_env("VAR2", false)
    @test Jive.compat_get_bool_env("VAR3", true)
end

end # module test_jive_runtests_compat
