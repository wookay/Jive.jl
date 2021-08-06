module test_jive_runtests_get_all_files

using Test
using Jive

dir = normpath(@__DIR__, "..") # Jive/test/jive/
skip = String[]
targets = ["//./pipe", "USE_REVISE", "USE_PLOTPANE", "runtests/get_all_files"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["runtests/get_all_files.jl"]


dir = normpath(@__DIR__, ".") # Jive/test/jive/runtests/
skip = String[]
targets = ["//./pipe", "USE_REVISE", "USE_PLOTPANE", "get_all_files"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["get_all_files.jl"]


dir = normpath(@__DIR__, "../../Example/test/example") # Jive/test/Example/test/example
skip = String[]

targets = ["test"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["test1.jl", "test2.jl"]

targets = ["test1"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test all_files == ["test1.jl"]

targets = ["abc"]
(all_files, start_idx) = Jive.get_all_files(dir, skip, targets)
@test isempty(all_files)

end # module test_jive_runtests_get_all_files
