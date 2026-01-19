module test_test_warn_nowarn

using Test

function test_warnings()
    @test_warn "warning" println(stderr, :warning)

    if VERSION >= v"1.8.0-DEV.363"
        @test_warn "warning" (@warn :warning)
    end

    @test_nowarn (1 + 2)
end


if stderr isa Base.TTY
    test_warnings()
else
    using Base.CoreLogging: ConsoleLogger, with_logger
    logger = ConsoleLogger()
    with_logger(test_warnings, logger)
end

end # module test_test_warn_nowarn
