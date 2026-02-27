module test_jive_runtests_compat

using Test
using Jive

ts = @testset "empty" begin
end

tc = Jive.get_test_counts(ts)
@test !(@inferred Jive.anynonpass(tc))

@test !(@inferred Jive.anynonpass(ts))

end # module test_jive_runtests_compat
