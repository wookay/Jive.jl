using Test
using Jive

context_variable = 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, verbose=false) # default context=nothing
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=nothing, verbose=false)
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=Main, verbose=false)
@test context_variable == 1

@test nameof(@__MODULE__()) === :anonymous
runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=@__MODULE__, verbose=false)
@test context_variable == 3



module test_jive_runtests_context

using Test
using Jive

context_variable = 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, verbose=false) # default context=nothing
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=nothing, verbose=false)
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=Main, verbose=false)
@test context_variable == 1

@test nameof(@__MODULE__()) === :test_jive_runtests_context
runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=@__MODULE__, verbose=false)
@test context_variable == 3

runtests(@__DIR__, targets=["target2"], enable_distributed=false, verbose=false)

end # module test_jive_runtests_context
