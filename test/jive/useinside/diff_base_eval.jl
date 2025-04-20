module test_useinside_diff_base_eval

using Test

module B
end

Base.@eval B module C
    g = 1
end

@test B.C.g == 1


using Jive
@useinside B module D
    h = 2
end

@test B.h == 2

end # module test_useinside_diff_base_eval
