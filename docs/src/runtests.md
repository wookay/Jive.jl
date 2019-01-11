# runtests

run the test files from the specific directory.

```@docs
Jive.runtests
```

```julia
using Jive # runtests
runtests(@__DIR__)
```
![runtests.svg](https://wookay.github.io/docs/Jive.jl/assets/jive/runtests.svg)

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
~/.julia/dev/Jive/test $ julia --color=yes -p1 runtests.jl
```

* distributed run tests for `Pkg.test()`, using `JIVE_PROCS` ENV.
```sh
~/.julia/dev/Jive $ JIVE_PROCS=2 julia --color=yes --project=. -e 'using Pkg; Pkg.test()'

~/.julia/dev/Jive $ julia --color=yes --project=. -e 'ENV["JIVE_PROCS"]="2"; using Pkg; Pkg.test()'
```
