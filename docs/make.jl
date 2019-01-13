using Jive
using Documenter

makedocs(
    build = joinpath(@__DIR__, "local" in ARGS ? "build_local" : "build"),
    modules = [Jive],
    clean = false,
    format = Documenter.HTML(prettyurls = !("local" in ARGS)),
    sitename = "Jive.jl 👣",
    authors = "WooKyoung Noh",
    pages = Any[
        "Home" => "index.md",
        "runtests" => "runtests.md",
        "watch" => "watch.md",
        "@skip" => "skip.md",
        "@onlyonce" => "onlyonce.md",
        "@If" => "If.md",
        "@useinside" => "useinside.md",
        "@mockup" => "mockup.md",
    ],
)
