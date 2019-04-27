module test_jive__END__

using Test

stack = []

try
    include("included.jl")
catch
    push!(stack, 1)
end

try
    include("included.jl")
catch
    push!(stack, 2)
end

push!(stack, 3)

@test stack == [10, 1, 10, 2, 3]

end # module test_jive__END__
