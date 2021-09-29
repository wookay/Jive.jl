module test_jive_runtests_context

using Test
using Jive

context_variable = 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=nothing)
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false) # default context=nothing
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=@__MODULE__)
@test context_variable == 3

end # module test_jive_runtests_context
