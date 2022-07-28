# julia 1.6.0-DEV.1437 commit 68c71f577275a16fffb743b2058afdc2d635068f
module test_testset_verbose

using Test

@testset "Verbose 1" verbose = true begin
    @testset "Verbose 2" begin
        @test true
    end
end

end # module test_testset_verbose


# julia 1.9.0-DEV.623 commit 88def1afe16acdfe41b15dc956742359d837ce04
module test_testset_failfast

using Test

@testset failfast = true begin
    @test true
end

end # module test_testset_failfast


using Jive
@If VERSION >= v"1.8.0-DEV.809" module test_testset_42518

using Test

function foo()
    @test true
end

function bar(n)
    @test n > 1
end

@testset foo()
@testset bar(2)

end # module test_testset_42518


module test_testset_let

using Test
using Jive

@testset let (fname, events) = ("fpath", [])
    @test fname == "fpath"
end

end # module test_testset_let
