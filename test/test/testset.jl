module test_testset_verbose

using Test

if VERSION >= v"1.6.0-DEV.1437"
    @testset "Verbose 1" verbose = true begin
        @testset "Verbose 2" begin
            @test true
        end
    end
end

end # module test_testset_verbose



using Jive
@If  VERSION >= v"1.8.0-DEV.809" module test_testset_42518

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


module test_testset_failfast

using Test

# julia 1.9.0-DEV.623 commit 88def1afe16acdfe41b15dc956742359d837ce04
@testset failfast = true begin
    @test true
end

end # module test_testset_failfast
