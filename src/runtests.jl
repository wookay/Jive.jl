# module Jive

using Test # @testset

function run(dir::String, tests::Vector{String})
    n_passed = 0
    anynonpass = 0
    for (idx, subpath) in enumerate(tests)
        filepath = normpath(dir, subpath) 
        numbering = string(idx, /, length(tests))
        ts = @testset "$numbering $subpath" begin
            Main.include(filepath)
        end
        n_passed += ts.n_passed
        anynonpass += ts.anynonpass
    end
    if iszero(anynonpass) && n_passed > 0
        printstyled("✅  ", color=:green)
        print("All ")
        printstyled(n_passed, color=:green)
        print(" ")
        print(n_passed == 1 ? "test has" : "tests have")
        print(" been completed.")
        println()
    end
end

"""
    runtests(dir::String)

run the test files from the specific directory.
"""
function runtests(dir::String)
    all_tests = Vector{String}()
    for (root, dirs, files) in walkdir(dir)
        for filename in files
            !endswith(filename, ".jl") && continue
            "runtests.jl" == filename && continue
            subpath = relpath(normpath(root, filename), dir)
            !isempty(ARGS) && !any(x->startswith(subpath, x), ARGS) && continue
            push!(all_tests, subpath)
        end
    end
    run(dir, all_tests)
end

# module Jive
