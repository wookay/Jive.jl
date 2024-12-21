using Test

@testset "issue 63" begin
    @test_logs (:warn, "msg") nothing
end
