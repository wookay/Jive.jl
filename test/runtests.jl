using Jive # runtests
# JIVE_SKIP=Example,errors,jive/onlyonce/heavy.jl,jive/__END__/included.jl,jive/__REPL__ julia runtests.jl
runtests(@__DIR__, skip=["Example", "errors", "jive/onlyonce/heavy.jl", "jive/__END__/included.jl", "jive/__REPL__"])
