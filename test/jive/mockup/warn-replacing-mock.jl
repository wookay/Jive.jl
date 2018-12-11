# warned against evaling inside a macro
# https://github.com/JuliaLang/METADATA.jl/pull/19955#issuecomment-445963293

module test_jive_mockup_warn_replacing_mock

using Jive # Mock @mockup
using Test

Jive.config[:warn_replacing_mock] = true

module Goods
x = 1
f() = x
end

@mockup module Goods
f() = x+2
end

@test Mock.Goods.f() == 3

end # module test_jive_mockup_warn_replacing_mock
