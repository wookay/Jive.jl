module test_jive_testset

using Test
using Jive

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset=nothing)
@test total isa Jive.Total
@test total.elapsed_time >= 0
@test total.n_passes == 2

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset="hello")
@test total.n_passes == 1

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset=["hello", "world"])
@test total.n_passes == 2

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset=r"^hello")
@test total.n_passes == 1

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset=startswith("he"))
@test total.n_passes == 1

total = runtests(@__DIR__, targets=["target3"], enable_distributed=false, verbose=false, testset=endswith("llo"))
@test total.n_passes == 1

end # module test_jive_testset
