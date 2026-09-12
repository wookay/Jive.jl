module test_testset

using Test

@testset "basic" begin
    @test 3 == 1+2
end

end # module test_testset
