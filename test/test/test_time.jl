module test_test_time

using Test

if VERSION >= v"1.6"
    redirect_stdout(devnull) do
        @time :ok
        @time :ok
        @time :ok
    end
end

end # module test_test_time
