module test_jive_time_expr

using Test
using Jive

function run_exprs()
    @test (@time_expr 1 + 2) == 3

    @time_expr val = 1 + 2
    @test val == 3
end

output = @sprint_plain(run_exprs())
@test startswith(output, "@time 1 + 2\n  0.00")

output = @sprint_colored(run_exprs())
# print(output)

end # module test_jive_time_expr
