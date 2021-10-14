# Jive.jl 👣

|  **Documentation**                        |  **Build Status**                                                  |
|:-----------------------------------------:|:------------------------------------------------------------------:|
|  [![][docs-latest-img]][docs-latest-url]  |  [![][actions-img]][actions-url]  [![][codecov-img]][codecov-url]  |


`Jive.jl` is a Julia package to help the writing tests.

 * ☕️  You can [make a donation](https://wookay.github.io/donate/) to support this project.


  - [runtests](#runtests)
  - [watch](#watch-package-folders)
  - [@skip](#skip)
  - [@onlyonce](#onlyonce)
  - [@If](#If)
  - [@useinside](#useinside)
  - [`@__END__`](#__end__)
  - [`@__REPL__`](#__repl__)


# runtests

run the test files in a specific directory and path.

suppose you have some test files in the `test/` directory for your package.
now let's make your `test/runtests.jl` with

```julia
using Jive
runtests(@__DIR__)
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)

for the `runtests.jl`, `ARGS` are used to filter the targets and to set the start offset of the tests.

```
~/.julia/dev/Jive/test $ julia runtests.jl jive/s start=3
1/4 jive/skip/skip-calls.jl --
2/4 jive/skip/skip-exprs.jl --
3/4 jive/skip/skip-functions.jl
    Pass 4  (0.40 seconds)
4/4 jive/skip/skip-modules.jl
    Pass 4  (0.01 seconds)
✅  All 8 tests have been completed.  (0.62 seconds)
```

in the above example, test files are matched for only have `jive/s` and jumping up to the 3rd file.

### Examples

* run tests
```sh
~/.julia/dev/Jive/test $ julia runtests.jl
```

* run tests with target directory.
```sh
~/.julia/dev/Jive/test $ julia runtests.jl jive/If
```

* distributed run tests with `-p`
```sh
~/.julia/dev/Jive/test $ julia -p3 runtests.jl
```

* distributed run tests for `Pkg.test()`, using `JIVE_PROCS` ENV.
```sh
~/.julia/dev/Jive $ JIVE_PROCS=2 julia --project=. -e 'using Pkg; Pkg.test()'

~/.julia/dev/Jive $ julia --project=. -e 'ENV["JIVE_PROCS"]="2"; using Pkg; Pkg.test()'
```

[TestJive.jl](https://github.com/wookay/TestJive.jl) is an example package for using Jive.
look at also the `test/Project.toml` file for your own package.
```toml
[deps]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"
Jive = "ba5e3d4b-8524-549f-bc71-e76ad9e9deed"

[targets]
test = ["Test", "Jive"]
```


# Watch package folders

You may need to install [Revise.jl](https://github.com/timholy/Revise.jl).

```sh
~/.julia/dev/Jive/test/Example/test $ cat runtests.jl
using Jive
runtests(@__DIR__, skip=["revise.jl"])

~/.julia/dev/Jive/test/Example/test $ cat revise.jl
# julia -i -q --project=. revise.jl example

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

~/.julia/dev/Jive/test/Example/test $ julia -e 'using Pkg; pkg"dev Revise .."'

~/.julia/dev/Jive/test/Example/test $ julia -i -q --project=. revise.jl example
watching folders ...
  - ../src
  - example
changed
1/1 example/test1.jl
    Pass 1  (0.27 seconds)
✅  All 1 test has been completed.  (0.55 seconds)
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


# `@__END__`

`throw(Jive.EndError())`

* [`test/jive/__END__`](https://github.com/wookay/Jive.jl/blob/master/test/jive/__END__)

```julia
using Jive
@__END__
```


# `@__REPL__`

* [`test/jive/__REPL__`](https://github.com/wookay/Jive.jl/blob/master/test/jive/__REPL__)

```
~/.julia/dev/Jive/test/jive/__REPL__ $ cat test.jl
using Jive

a = 1

@__REPL__

@info :a a
~/.julia/dev/Jive/test/jive/__REPL__ $ julia test.jl
julia> a += 2
3

julia> ^D  # Ctrl + D to exit the REPL
┌ Info: a
└   a = 3
```


[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://wookay.github.io/docs/Jive.jl/

[actions-img]: https://github.com/wookay/Jive.jl/workflows/CI/badge.svg
[actions-url]: https://github.com/wookay/Jive.jl/actions

[codecov-img]: https://codecov.io/gh/wookay/Jive.jl/branch/master/graph/badge.svg
[codecov-url]: https://codecov.io/gh/wookay/Jive.jl/branch/master
