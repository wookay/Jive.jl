# module Jive

onlyonce_evaluated = Set{LineNumberNode}()
onlyonce_called = Set{String}()

"""
    @onlyonce(block)

used to run the block only once.
"""
macro onlyonce(block)
    line = block.args[1]
    if line in Jive.onlyonce_evaluated
        nothing
    else
        push!(Jive.onlyonce_evaluated, line)
        linestr = string(line.file, "#", line.line)
        lineinexpr = Expr(:call, :in, linestr, :(Jive.onlyonce_called))
        quot = Expr(:if, lineinexpr, nothing, quote
            push!(Jive.onlyonce_called, $linestr)
            $block
        end)
        esc(quot)
    end
end

# module Jive
