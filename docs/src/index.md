# Jive 👣

`Jive.jl` is a Julia package to help the writing tests.

  - [runtests](#runtests)
  - [watch](#watch)
  - [@skip](#skip)
  - [@onlyonce](#onlyonce)
  - [@If](#If)
  - [@useinside](#useinside)
  - [@mockup](#mockup)


# runtests

run the test files from the specific directory.

```julia
using Jive
runtests(@__DIR__, skip=[], node1=[])
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)

for the `runtests.jl`, `ARGS` are used to filter the targets and to set the first one to test.

```
~/.julia/dev/Jive/test $ julia --color=yes runtests.jl jive/s jive/m start=3
1/5 jive/mockup/mockup.jl --
2/5 jive/mockup/warn-replacing-mock.jl --
3/5 jive/skip/skip-calls.jl
    Pass 2  (0.26 seconds)
4/5 jive/skip/skip-functions.jl
    Pass 4  (0.01 seconds)
5/5 jive/skip/skip.jl
    Pass 4  (0.01 seconds)
✅  All 10 tests have been completed.  (0.57 seconds)
```

in the above example, test files are matched for only have `jive/s` `jive/m` and jump up to the 3rd file.

### Examples

* run tests
```sh
~/.julia/dev/Jive/test $ julia --color=yes runtests.jl
```

* run tests with target directory.
```sh
~/.julia/dev/Jive/test $ julia --color=yes runtests.jl jive/If
```

* distributed run tests with `-p`
```sh
~/.julia/dev/Jive/test $ julia --color=yes -p3 runtests.jl
```

* distributed run tests for `Pkg.test()`, using `JIVE_PROCS` ENV.
```sh
~/.julia/dev/Jive $ JIVE_PROCS=2 julia --color=yes --project=. -e 'using Pkg; Pkg.test()'

~/.julia/dev/Jive $ julia --color=yes --project=. -e 'ENV["JIVE_PROCS"]="2"; using Pkg; Pkg.test()'
```


# watch

watch the folders.

```sh
~/.julia/dev/Jive/test/Example/test $ cat runtests.jl
using Jive
runtests(@__DIR__, skip=["revise.jl"])

~/.julia/dev/Jive/test/Example/test $ cat revise.jl
using Revise, Jive
using Example
watch(@__DIR__, sources=[pathof(Example)]) do path
    @info :changed path
    revise()
    runtests(@__DIR__, skip=["revise.jl"])
end
# Jive.stop(watch)

~/.julia/dev/Jive/test/Example/test $ julia --project=.. -q -i revise.jl example
watching folders ...
  - example
  - ../src
```

when saving any files in the watching folders, it automatically run tests.


# @skip

skip a module, function, or call.

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

  - Change to don't skip the code: set `ENV["JIVE_SKIP"] = "0"`


# @onlyonce

used to run the block only once.

* [test/jive/onlyonce](https://github.com/wookay/Jive.jl/tree/master/test/jive/onlyonce)

```julia
using Jive # @onlyonce

@onlyonce begin
    println(42)
end
```


# @If

evaluate the module by the condition.

* [test/jive/If](https://github.com/wookay/Jive.jl/blob/master/test/jive/If)

```julia
using Jive # @If
@If VERSION >= v"1.1.0-DEV.764" module load_some_module
end
```


# @useinside

use inside of the module.

```julia
using Jive # @useinside
@useinside module test_pkgs_flux_optimise
# ...
end
```


# @mockup

used to produce a replica from the other module.

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
