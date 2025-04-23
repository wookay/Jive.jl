module test_jive_skip_exprs

using Jive # Skipped @skip
using Test # @test

empty!(Jive.Skipped.expressions)

@skip if 3 > 2
end

@skip quote
end

@skip begin
end

@skip macro m()
end

@skip using Jive, Test

@skip return

@skip f() do x
end

@skip struct A
end

@skip mutable struct B
end

@skip :hello
@skip true
@skip pi
@skip 42
@skip nothing
@skip a = 2
@skip [1,2,3]

@skip for i in 1:2
end

@test Jive.Skipped.expressions == [:if, :quote, :block, :macro=>:m, :using, :return, :do, :struct=>:A, :struct=>:B, :hello, true, :pi, 42, nothing, :(=), :vect, :for]
@test !isdefined(@__MODULE__, :a)


empty!(Jive.Skipped.expressions)
ENV["JIVE_ENABLE_SKIP_MACRO"] = "0"

@skip if 10 > 2
end

@skip :hello
@skip true
@skip pi
@skip 42
@skip nothing
@skip a = 2
@skip [1,2,3]

@test isempty(Jive.Skipped.expressions)
@test isdefined(@__MODULE__, :a)

ENV["JIVE_ENABLE_SKIP_MACRO"] = "1"

end # module test_jive_skip_exprs
