# module Jive

onlyonce_evaluated = Dict{String,UInt}()
onlyonce_called = Dict{String,UInt}()

"""
    @onlyonce(block)

used to run the block only once.
"""
macro onlyonce(block)
    h = hash(block)
    if block.head === :block
        node = block.args[1]
        dir = pwd()
        linestr = string(relpath(String(node.file), dir), "#", node.line)
        haskey(onlyonce_evaluated, linestr) && h == onlyonce_evaluated[linestr] && return nothing
        onlyonce_evaluated[linestr] = h
    else
        linestr = string(block)
    end
    quot = quote
        if haskey(Jive.onlyonce_called, $linestr) && $h == Jive.onlyonce_called[$linestr]
            nothing
        else
            Jive.onlyonce_called[$linestr] = $h
            $block
        end
    end
    esc(quot)
end

# module Jive
