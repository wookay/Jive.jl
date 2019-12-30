# runtests

run the test files from the specific directory.

```@docs
Jive.runtests
```

```julia
using Jive
runtests(@__DIR__, skip=[], node1=[], targets=ARGS)
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)

for the `runtests.jl`, `ARGS` are used to filter the targets and to set the start offset of the tests.

```
~/.julia/dev/Jive/test $ julia --color=yes runtests.jl jive/s start=3
1/4 jive/skip/skip-calls.jl --
2/4 jive/skip/skip-exprs.jl --
3/4 jive/skip/skip-functions.jl
    Pass 4  (0.37 seconds)
4/4 jive/skip/skip-modules.jl
    Pass 4  (0.01 seconds)
✅   All 8 tests have been completed.  (0.65 seconds)
```

in the above example, test files are matched for only have `jive/s` and jumping up to the 3rd file.

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

see also [travis job logs](https://travis-ci.org/wookay/Jive.jl/jobs/483203342#L452).
