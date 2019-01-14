val = 42

using Jive

@onlyonce begin
    sleep(0.1)
    val = 0
end
