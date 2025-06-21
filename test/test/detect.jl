module test_test_detect

using Test
using Jive

# function detect_ambiguities(mods::Module...;
#                             recursive::Bool = false,
#                             ambiguous_bottom::Bool = false,
#                             allowed_undefineds = nothing) # v1.8
ambs = detect_ambiguities(Test, Jive)
@test isempty(ambs)

# function detect_unbound_args(mods...;
#                              recursive::Bool = false,
#                              allowed_undefineds=nothing) # v1.8
ambs = detect_unbound_args(Test, Jive)
@test isempty(ambs)

end # module test_test_detect
