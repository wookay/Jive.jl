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
