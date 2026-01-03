using Jive
@If VERSION >= v"1.11" module test_test_context
# @If VERSION >= v"1.14.0-DEV.1453" module test_test_context

using Test

c = :context
@test true context=c

end # module test_test_context
