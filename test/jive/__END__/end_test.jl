module test_jive_end_test

using Test

included_stack = Int[]

try
    include("included.jl")
catch
    push!(included_stack, 1)
end

try
    include("included.jl")
catch
    push!(included_stack, 2)
end

push!(included_stack, 3)

@test included_stack == [10, 1, 10, 2, 3]

end # module test_jive_end_test
