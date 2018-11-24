# Jive 👣

* `@mockup` ([test/jive/mockup](https://github.com/wookay/Jive.jl/blob/master/test/jive/mockup))
```julia
using Jive # Mock @mockup
using Test

module Goods
struct Foo
end
function f(::Foo)
    10
end
function g(::Foo)
    10
end
end # module Goods


@mockup module Goods
function f(::Foo)
    20
end
end # @mockup module Goods
@test Goods.f(Goods.Foo()) == 10
@test Mock.Goods.f(Mock.Goods.Foo()) == 20
@test Mock.Goods.g(Mock.Goods.Foo()) == 10


Goods3 = @mockup module Goods
function g(::Foo)
    30
end
end # @mockup module Goods
@test Goods.f(Goods.Foo()) == 10
@test Mock.Goods.f(Mock.Goods.Foo()) == 10
@test Mock.Goods.g(Mock.Goods.Foo()) == 30
@test Goods3 isa Module
@test Goods3.g === Mock.Goods.g
```


* `@onlyonce` ([test/jive/onlyonce](https://github.com/wookay/Jive.jl/tree/master/test/jive/onlyonce))
```julia
using Jive # @onlyonce

@onlyonce begin
    println(42)
end
```


* `@skip` ([test/jive/skip](https://github.com/wookay/Jive.jl/blob/master/test/jive/skip/skip.jl))
```julia
using Jive # @skip

ENV["JIVE_SKIP"] = "1"   # "0"

@skip module want_to_skip_this_module
sleep(3)
end

Jive.Skipped.modules
```
