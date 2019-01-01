# Jive 👣

`Jive.jl` is a Julia package to help the writing tests.

  - [@mockup](#mockup) the modules
  - [@onlyonce](#onlyonce) run
  - [@skip](#skip) the code
  - [@If](#If) module
  - [runtests](#runtests)


### @mockup

* [test/jive/mockup](https://github.com/wookay/Jive.jl/blob/master/test/jive/mockup)

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


### @onlyonce

* [test/jive/onlyonce](https://github.com/wookay/Jive.jl/tree/master/test/jive/onlyonce)

```julia
using Jive # @onlyonce

@onlyonce begin
    println(42)
end
```


### @skip

* [test/jive/skip](https://github.com/wookay/Jive.jl/blob/master/test/jive/skip)

```julia
using Jive # @skip

@skip module want_to_skip_this_module
sleep(2)
end

@skip function want_to_skip_this_function()
sleep(2)
end

@skip println(1+2)

Jive.Skipped.modules
Jive.Skipped.functions
Jive.Skipped.calls
```

  - Do not skip the code: `ENV["JIVE_SKIP"] = "0"`


### @If

* [test/jive/If](https://github.com/wookay/Jive.jl/blob/master/test/jive/If)

```julia
using Jive # @If
@If VERSION >= v"1.1.0-DEV.764" module load_some_module
end
```


### runtests

* [test/runtests.jl](https://github.com/wookay/Jive.jl/blob/master/test/runtests.jl)

```julia
using Jive # runtests
runtests(@__DIR__)
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)
