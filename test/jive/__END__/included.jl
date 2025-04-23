if !@isdefined(included_stack)
    printstyled("you need to run end_test.jl first\n", color = :red)
end

using Jive
push!(included_stack, 10)
@__END__
push!(included_stack, 20)
