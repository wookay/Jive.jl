# module Jive

onlyonce_evaluated = Set{LineNumberNode}()

"""
    @onlyonce(block)

used to run the block only once.
"""
macro onlyonce(block)
    line = block.args[1]
    if line in onlyonce_evaluated
        nothing
    else
        push!(onlyonce_evaluated, line)
        esc(block)
    end
end

# module Jive
