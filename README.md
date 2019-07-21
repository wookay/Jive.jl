# Jive 👣

|  **Documentation**                        |  **Build Status**                                                |
|:-----------------------------------------:|:----------------------------------------------------------------:|
|  [![][docs-latest-img]][docs-latest-url]  |  [![][travis-img]][travis-url]  [![][codecov-img]][codecov-url]  |


`Jive.jl` is a Julia package to help the writing tests.

 * ☕️  You can [make a donation](https://wookay.github.io/donate/) to support this project.


  - [runtests](#runtests)
  - [watch](#watch-package-folders)
  - [@skip](#skip)
  - [@onlyonce](#onlyonce)
  - [@If](#If)
  - [@useinside](#useinside)
  - [@mockup](#mockup)
  - [`@__END__`](#__end__)


# runtests

run the test files from the specific directory.

```julia
using Jive
runtests(@__DIR__, skip=[], node1=[], targets=ARGS)
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)

for the `runtests.jl`, `ARGS` are used to filter the targets and to set the start offset of the tests.

```
~/.julia/dev/Jive/test $ julia --color=yes runtests.jl jive/s jive/m start=3
1/5 jive/mockup/mockup.jl --
2/5 jive/skip/skip-calls.jl --
3/5 jive/skip/skip-exprs.jl
    Pass 4  (0.38 seconds)
4/5 jive/skip/skip-functions.jl
    Pass 4  (0.05 seconds)
5/5 jive/skip/skip-modules.jl
    Pass 4  (0.01 seconds)
✅  All 12 tests have been completed.  (0.73 seconds)
```

in the above example, test files are matched for only have `jive/s` `jive/m` and jumping up to the 3rd file.

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

see also [travis job logs](https://travis-ci.org/wookay/Jive.jl/jobs/483203342#L452) and [TestJive.jl](https://github.com/wookay/TestJive.jl).


# Watch package folders

You may need to install [Revise.jl](https://github.com/timholy/Revise.jl).

```sh
~/.julia/dev/Jive/test/Example/test $ cat runtests.jl
using Jive
runtests(@__DIR__, skip=["revise.jl"])

~/.julia/dev/Jive/test/Example/test $ cat revise.jl
# julia -i -q --color=yes --project=.. revise.jl example

using Revise, Jive
using Example

trigger = function (path)
    printstyled("changed ", color=:cyan)
    println(path)
    revise()
    runtests(@__DIR__, skip=["revise.jl"])
end

watch(trigger, @__DIR__, sources=[pathof(Example)])
trigger("")

Base.JLOptions().isinteractive==0 && wait()

~/.julia/dev/Jive/test/Example/test $ julia -i -q --color=yes --project=.. revise.jl example
watching folders ...
  - ../src
  - example
```

when saving any files in the watching folders, it automatically run tests.


# @skip

skip the expression.

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
```

  - Change to do not skip the code: set `ENV["JIVE_SKIP"] = "0"`


# @onlyonce

used to run the block only once.

* [test/jive/onlyonce](https://github.com/wookay/Jive.jl/tree/master/test/jive/onlyonce)

```julia
using Jive # @onlyonce

for _ in 1:10
    @onlyonce begin
        println(42)
    end
    @onlyonce(println("hello"))
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


# `@__END__`

`throw(Jive.EndError())`

* [`test/jive/__END__`](https://github.com/wookay/Jive.jl/blob/master/test/jive/__END__)

```julia
using Jive
@__END__
```


[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://wookay.github.io/docs/Jive.jl/

[travis-img]: https://api.travis-ci.org/wookay/Jive.jl.svg?branch=master
[travis-url]: https://travis-ci.org/wookay/Jive.jl

[codecov-img]: https://codecov.io/gh/wookay/Jive.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/wookay/Jive.jl/branch/master
