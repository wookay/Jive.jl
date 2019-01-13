# watch

watch the folders.

```@docs
Jive.watch
Jive.stop
```

```
~/.julia/dev/Jive/test $ julia --color=yes -q -i runtests.jl jive/s
1/3 jive/skip/skip-calls.jl
    Pass 2  (0.29 seconds)
2/3 jive/skip/skip-functions.jl
    Pass 4  (0.02 seconds)
3/3 jive/skip/skip.jl
    Pass 4  (0.01 seconds)
✅  All 10 tests have been completed.  (0.61 seconds)
julia> watch(@__DIR__, sources=[normpath(@__DIR__,"..","src")]) do path
           @info :changed path
           runtests(@__DIR__)
       end
watching folders ...
  - jive/skip
  - ../src
```

when saving any files in the watching folders, it automatically run tests.

```julia
julia> ┌ Info: changed
└   path = "jive/skip/skip.jl"
1/3 jive/skip/skip-calls.jl
    Pass 2  (0.00 seconds)
2/3 jive/skip/skip-functions.jl
    Pass 4  (0.01 seconds)
3/3 jive/skip/skip.jl
    Pass 4  (0.01 seconds)
✅  All 10 tests have been completed.  (0.15 seconds)
```

to stop watching

```julia
julia> Jive.stop(watch)
stopped watching folders.
```
