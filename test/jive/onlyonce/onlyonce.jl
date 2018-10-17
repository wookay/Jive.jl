module test_jive_onlyonce

function read_stdout(f)
    oldout = stdout
    rdout, wrout = redirect_stdout()
    out = @async read(rdout, String)
    f()
    redirect_stdout(oldout)
    close(wrout)
    rstrip(fetch(out))
end

output = read_stdout() do
    include("heavy")
    include("heavy")
    include("heavy")
end

using Test
@test output == "42"

end # module test_jive_onlyonce
