using Jive
@If VERSION >= v"1.13.0-DEV.1070" module test_scoped_values # julia commit 5fb39c695e93d5f13a95d57ffa4c537a79f11b58

using Test

# Test.TESTSET_PRINT_ENABLE
# julia 1.13.0-DEV.1044
# bb368512880ca6cf051a91993c9c5bb4a8d3b7d0

# Test.TEST_RECORD_PASSES
# julia 1.13.0-DEV.1070
# 5fb39c695e93d5f13a95d57ffa4c537a79f11b58

@Base.ScopedValues.with Test.TESTSET_PRINT_ENABLE=>false Test.TEST_RECORD_PASSES=>false begin
    @test Test.TESTSET_PRINT_ENABLE[] === false
    @test Test.TEST_RECORD_PASSES[] === false
end

@test Test.TEST_RECORD_PASSES[] === Base.get_bool_env("JULIA_TEST_RECORD_PASSES", false)

# Test.VERBOSE_TESTSETS
# julia 1.13.0-DEV.1075
# 0b392261107b76e91511bac4a82454b938b5c780
if VERSION >= v"1.13.0-DEV.1075"
@test Test.VERBOSE_TESTSETS[] === Base.get_bool_env("JULIA_TEST_VERBOSE", false)
end

end # module test_scoped_values
