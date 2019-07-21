# @onlyonce

used to run the block only once.

```@docs
Jive.@onlyonce
```

```julia
using Jive # @onlyonce

for _ in 1:10
    @onlyonce begin
        println(42)
    end
    @onlyonce(println("hello"))
end
```
