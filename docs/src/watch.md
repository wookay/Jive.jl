# watch

watch the folders.

!!! note
    😭 it doesn't work as expected.

You may need to install [Revise.jl](https://github.com/timholy/Revise.jl).

```@docs
Jive.watch
Jive.stop
```

```sh
~/.julia/dev/TestJiveRunMoreTestsJive/test/ExampleRevise/test $ cat runtests.jl
using Jive
runtests(@__DIR__, skip=["revise.jl"])

~/.julia/dev/TestJiveRunMoreTestsJive/test/ExampleRevise/test $ cat revise.jl
# julia -i -q --project=. revise.jl example

using Revise, Jive
using ExampleRevise
watch(@__DIR__, sources=[pathof(ExampleRevise)]) do path
    @info :changed path
    revise()
    runtests(@__DIR__, skip=["revise.jl"])
end
# Jive.stop(watch)

~/.julia/dev/TestJiveRunMoreTestsJive/test/ExampleRevise/test $ julia -e 'using Pkg; pkg"dev Revise .."'

~/.julia/dev/TestJiveRunMoreTestsJive/test/ExampleRevise/test $ julia --project=. -q -i revise.jl example
watching folders ...
  - ../src
  - example
```

when saving any files in the watching folders, it automatically run tests.

```julia
julia> ┌ Info: changed
└   path = "../src/ExampleRevise.jl"
1/1 example/test1.jl
    Pass 1  (0.26 seconds)
✅  All 1 test has been completed.  (0.55 seconds)
┌ Info: changed
└   path = "example/test1.jl"
1/1 example/test1.jl
    Pass 1  (0.00 seconds)
✅  All 1 test has been completed.  (0.00 seconds)
```

to stop watching

```julia
julia> Jive.stop(watch)
stopped watching folders.
```
