module test_test_logs

using Test

@test_logs (:info, "foo") @info "foo"

function f()
    @info "bar"
    @info "baz"
    :ok
end
@test (@test_logs (:info, "bar") (:info, "baz") f()) === :ok

end # module test_test_logs
