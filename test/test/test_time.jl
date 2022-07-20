module test_test_time

using Test

if VERSION >= v"1.6"
    redirect_stdout(stdout) do
        @time  :ok
        @timev :ok
    end
end

@test true

end # module test_test_time
