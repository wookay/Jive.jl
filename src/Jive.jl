module Jive

export Mock, @mockup
include("mockup.jl")

export @skip
include("skip.jl")

export @onlyonce
include("onlyonce.jl")

export @If
include("If.jl")

export @useinside
include("useinside.jl")

export @__END__
include("__END__.jl")

export @__REPL__
include("__REPL__.jl")

export runtests
include("runtests.jl")

export watch
include("watch.jl")

end # module Jive
