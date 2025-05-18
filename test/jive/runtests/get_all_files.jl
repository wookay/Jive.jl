module test_jive_runtests_get_all_files

using Test
using Jive

skip = String[]
dir = normpath(@__DIR__, "../skip")
targets = ["skip-m", "skip-e", "skip-m"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test allunique(all_files)
@test all_files == ["skip-modules.jl", "skip-exprs.jl"]
@test start_idx == 1

targets = ["start=2"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["skip-calls.jl", "skip-exprs.jl", "skip-functions.jl", "skip-modules.jl"]
@test start_idx == 2

dir = @__DIR__
targets = ["start="]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test start_idx == 1

end # module test_jive_runtests_get_all_files
