# `@__REPL__`

```@docs
Jive.@__REPL__
```

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
