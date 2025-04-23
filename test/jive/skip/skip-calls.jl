module test_jive_skip_calls

using Jive # Skipped @skip
using Test # @test

empty!(Jive.Skipped.expressions)

function want_to_skip()
sleep(3)
print(:dont_print_it)
end

@skip want_to_skip()
@test Jive.Skipped.expressions == [:call => :want_to_skip]


ENV["JIVE_ENABLE_SKIP_MACRO"] = "0"

function non_skip()
end

@skip non_skip()
@test Jive.Skipped.expressions == [:call => :want_to_skip]

ENV["JIVE_ENABLE_SKIP_MACRO"] = "1"

end # module test_jive_skip_calls
