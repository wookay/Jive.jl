using Jive
@If VERSION >= v"1.11" module test_jive_ext_test_ext

using Jive
using Test

TestExt = Base.get_extension(Jive, :TestExt)
if VERSION >= v"1.14.0-DEV.1453"
    @test !isdefined(TestExt, :do_test_ext)
else
    @test TestExt.do_test_ext isa Function
end

end # module test_jive_ext_test_ext
