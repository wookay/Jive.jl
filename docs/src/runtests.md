# runtests

run the test files in a specific directory and path.

```@docs
Jive.runtests
```

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

[compat]
Jive = "0.3"
```

See [TestJiveRunMoreTests.jl](https://github.com/wookay/TestJiveRunMoreTests.jl) to care the advanced cases.
