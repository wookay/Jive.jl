module test_jive_skip_calls

using Jive # Skipped @skip
using Test # @test

empty!(Jive.Skipped.calls)

function want_to_skip()
sleep(3)
print(:dont_print_it)
end

@skip want_to_skip()
@test Jive.Skipped.calls == [:want_to_skip]


ENV["JIVE_SKIP"] = "0"

function non_skip()
end

@skip non_skip()
@test Jive.Skipped.calls == [:want_to_skip]

ENV["JIVE_SKIP"] = "1"

end # module test_jive_skip_calls
