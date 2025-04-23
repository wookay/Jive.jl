module test_jive_skip_functions

using Jive # Skipped @skip
using Test # @test

empty!(Jive.Skipped.expressions)

@skip function want_to_skip()
sleep(3)
print(:dont_print_it)
end

@test !isdefined(@__MODULE__, :want_to_skip)
@test Jive.Skipped.expressions == [:function =>:want_to_skip]


ENV["JIVE_ENABLE_SKIP_MACRO"] = "0"

@skip function non_skip()
end

@test isdefined(@__MODULE__, :non_skip)
@test Jive.Skipped.expressions == [:function=>:want_to_skip]

ENV["JIVE_ENABLE_SKIP_MACRO"] = "1"

end # module test_jive_skip_functions
