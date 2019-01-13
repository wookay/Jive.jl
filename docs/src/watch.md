# watch

watch the folders.

```@docs
Jive.watch
Jive.stop
```

```julia
julia> watch(@__DIR__, sources=[normpath(@__DIR__,"..","src")]) do path
           @info :changed path
           runtests(@__DIR__)
       end
watching folders ...
  - pkgs/flux
  - ../src
```

```julia
julia> Jive.stop(watch)
stopped watching folders.
```
