module test_test_throws

using Test

if v"1.8.0-DEV.364" > VERSION >= v"1.5"
@test_throws ArgumentError("reducing over an empty collection is not allowed") reduce(+, ())
end

if VERSION >= v"1.8.0-DEV.363"
@test_throws "reducing" reduce(+, ())
end

end # module test_test_throws
