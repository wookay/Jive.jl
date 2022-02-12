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


using Jive
@If VERSION >= v"1.8.0-DEV.1493" module test_testlogger

using Test, Logging

logger = TestLogger()
with_logger(logger) do
    @info 1493
end

l = first(logger.logs)
@test l isa LogRecord
@test l.message == 1493

end # module test_testlogger
