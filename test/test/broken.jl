module test_test_broken

using Test

@test_broken 1 == 2
@test_skip   1 == 2

if VERSION >= v"1.7.0-DEV.865"  # Julia PR #39322
@test 1 == 2 broken=true
@test 1 == 2 skip=true
end

end # module test_test_broken
