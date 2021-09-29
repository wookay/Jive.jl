using Test
using Jive

context_variable = 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, print_numbered_list=false) # default context=nothing
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=nothing, print_numbered_list=false)
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=Main, print_numbered_list=false)
@test context_variable == 1

@test nameof(@__MODULE__()) === :anonymous
runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=@__MODULE__, print_numbered_list=false)
@test context_variable == 3



module test_jive_runtests_context

using Test
using Jive

context_variable = 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, print_numbered_list=false) # default context=nothing
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=nothing, print_numbered_list=false)
@test context_variable == 1

runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=Main, print_numbered_list=false)
@test context_variable == 1

@test nameof(@__MODULE__()) === :test_jive_runtests_context
runtests(@__DIR__, targets=["target1"], enable_distributed=false, context=@__MODULE__, print_numbered_list=false)
@test context_variable == 3

end # module test_jive_runtests_context
