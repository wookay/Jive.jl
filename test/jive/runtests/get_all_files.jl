module test_jive_runtests_get_all_files

using Test
using Jive

dir = normpath(@__DIR__, "..")
skip = []
targets = ["//./pipe", "USE_REVISE", "USE_PLOTPANE", "runtests/get_all_files"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["runtests/get_all_files.jl"]

end # module test_jive_runtests_get_all_files
