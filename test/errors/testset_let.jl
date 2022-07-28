# julia 1.9.0-DEV.1055 commit ff1b563e3c6f3ee419de0f792c5ff42744448f1c
module test_errors_testset_let

using Test
using Jive

@testset let v=(1,2,3)
    @test v[1] == 1
    @test v[2] == 3
end

end # module test_errors_testset_let
