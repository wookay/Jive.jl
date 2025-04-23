# @skip

skip the expression.

```@docs
Jive.@skip
Jive.Skipped
```

* [test/jive/skip](https://github.com/wookay/Jive.jl/blob/master/test/jive/skip)

```julia
using Jive # @skip

@skip module want_to_skip_this_module
sleep(2)
end

@skip function want_to_skip_this_function()
sleep(2)
end

@skip println(1+2)
```

  - Change to do not skip the code: `ENV["JIVE_ENABLE_SKIP_MACRO"] = "0"`
