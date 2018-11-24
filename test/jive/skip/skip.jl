module test_jive_skip

using Jive # Skipped @skip
using Test # @test


@skip module want_to_skip
sleep(3)
print(:dont_print_it)
end

@test Jive.Skipped.modules == [:want_to_skip]


ENV["JIVE_SKIP"] = "0"

@skip module non_skip
end

@test Jive.Skipped.modules == [:want_to_skip]

ENV["JIVE_SKIP"] = "1"

end # module test_jive_mockup
