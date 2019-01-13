module test_jive_skip

using Jive # Skipped @skip
using Test # @test

empty!(Jive.Skipped.modules)

@skip module want_to_skip
sleep(3)
print(:dont_print_it)
end

@test !isdefined(@__MODULE__, :want_to_skip)
@test Jive.Skipped.modules == [:want_to_skip]


ENV["JIVE_SKIP"] = "0"

@skip module non_skip
end

@test isdefined(@__MODULE__, :non_skip)
@test Jive.Skipped.modules == [:want_to_skip]

ENV["JIVE_SKIP"] = "1"

end # module test_jive_mockup
