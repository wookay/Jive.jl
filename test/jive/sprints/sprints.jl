module test_jive_sprints

using Test
using Jive # sprint_plain sprint_colored

struct Foo
end

function Base.show(io::IO, mime::MIME"text/plain", foo::Foo)
    printstyled(io, "Foo", color = :light_green)
    print(io, "()")
end

@test endswith(string(Foo()), "test_jive_sprints.Foo()")
@test sprint_plain(Foo()) == "Foo()"
@test sprint_colored(Foo()) == "\e[92mFoo\e[39m()"

end # module test_jive_sprints
