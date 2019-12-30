using Jive # runtests
runtests(@__DIR__, skip=["Example", "errors", "jive/onlyonce/heavy.jl", "jive/__END__/included.jl", "jive/__REPL__"])
