module test_test_broken

using Test

@test_broken 1 == 2
@test_skip   1 == 2

end # module test_test_broken
