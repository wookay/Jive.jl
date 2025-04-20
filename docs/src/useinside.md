# @useinside

use inside of the module.

```@docs
Jive.@useinside
```

```julia
using Jive # @useinside
@useinside module test_pkgs_flux_optimise
# ...
end
```

`Main` is the module to evaluate in.
```julia
@useinside Main module test_pkgs_flux_optimise
# ...
end
```
