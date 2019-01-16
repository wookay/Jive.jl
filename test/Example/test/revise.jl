using Revise, Jive
using Example
watch(@__DIR__, sources=[pathof(Example)]) do path
    @info :changed path
    revise()
    runtests(@__DIR__, skip=["revise.jl"])
end
# Jive.stop(watch)

