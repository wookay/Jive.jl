# module Jive

if !isdefined(Main, :only_once_evaluated)
    only_once_evaluated = Set{LineNumberNode}()
end

macro onlyonce(block)
    line = block.args[1]
    if line in only_once_evaluated
        nothing
    else
        push!(only_once_evaluated, line)
        esc(block)
    end
end

# module Jive
