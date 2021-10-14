# watch

watch the folders.

```@docs
Jive.watch
Jive.stop
```

```sh
~/.julia/dev/Jive/test/Example/test $ cat runtests.jl
using Jive
runtests(@__DIR__, skip=["revise.jl"])

~/.julia/dev/Jive/test/Example/test $ cat revise.jl
# julia -i -q --project=. revise.jl example

using Revise, Jive
using Example
watch(@__DIR__, sources=[pathof(Example)]) do path
    @info :changed path
    revise()
    runtests(@__DIR__, skip=["revise.jl"])
end
# Jive.stop(watch)

~/.julia/dev/Jive/test/Example/test $ julia -e 'using Pkg; pkg"dev Revise .."'

~/.julia/dev/Jive/test/Example/test $ julia --project=. -q -i revise.jl example
watching folders ...
  - ../src
  - example
```

when saving any files in the watching folders, it automatically run tests.

```julia
julia> ┌ Info: changed
└   path = "../src/Example.jl"
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
