module test_test_time

using Test

redirect_stdout(devnull) do
    @time :ok
    @time :ok
    @time :ok
end

end # module test_test_time
