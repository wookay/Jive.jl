module test_test_warn_nowarn

using Test

@test_warn   "warning" println(stderr, :warning)

if VERSION >= v"1.8.0-DEV.363"
@test_warn   "warning" (@warn :warning)
end

@test_nowarn           (1 + 2)

end # module test_test_warn_nowarn
