module test_test_logs

using Test
using Logging: Info

@test_logs (Info,)  @info "foo"
@test_logs (:info,) @info "foo"

end # module test_test_logs
