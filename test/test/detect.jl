module test_test_detect

using Test
using Jive

# function detect_ambiguities(mods::Module...;
#                             recursive::Bool = false,
#                             ambiguous_bottom::Bool = false,
#                             allowed_undefineds = nothing) # v1.8
ambs = Test.detect_ambiguities(Test, Jive)
@test isempty(ambs)

# function detect_unbound_args(mods...;
#                              recursive::Bool = false,
#                              allowed_undefineds=nothing) # v1.8
ambs = Test.detect_unbound_args(Test, Jive)
@test isempty(ambs)

if VERSION >= v"1.14.0-DEV.1629"
# function detect_closure_boxes(mods::Module...)
@test isempty(Test.detect_closure_boxes(Jive))

# detect_closure_boxes_all_modules()
#   detect_closure_boxes(Base.loaded_modules_array()...)
Test.detect_closure_boxes_all_modules
end

end # module test_test_detect
