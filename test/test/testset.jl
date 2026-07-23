using Test

@testset "basic" begin
    @test 3 == 1+2
end

# from julia/stdlib/Test/test/runtests.jl
@testset "Child 1" verbose = true begin
@testset "Child 1.1 (long name)" begin
    @test 1 == 1
end
end

@testset "Child 2" begin
@testset "Child 2.1" begin
    @test 1 == 1
end
end
