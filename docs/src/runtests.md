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

set `JULIA_TEST_VERBOSE=true` to print the detailed hierarchical test summaries.
```
~/.julia/dev/Jive/test $ JULIA_TEST_VERBOSE=true julia test/testset.jl
Starting testset: basic
Finished testset: basic (0.0s)
Test Summary: | Pass  Total  Time
basic         |    1      1  0.0s

~/.julia/dev/Jive/test $ JULIA_TEST_VERBOSE=true julia runtests.jl test/testset.jl
1/1 test/testset.jl
Test Summary: | Pass  Total  Time
basic         |    1      1  0.1s
    Pass: 1  (compile: 0.28, recompile: 0.09, elapsed: 0.28 seconds)
✅  All 1 test has been completed.  (compile: 0.28, recompile: 0.09, elapsed: 0.28 seconds)
```

Refer to the [docs/runtests](https://wookay.github.io/docs/Jive.jl/runtests/) for details.

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
