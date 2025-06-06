using Jive
@useinside Main module test_jive_sprints

using Test
using Jive # sprint_plain sprint_colored

struct Foo
end

foo = Foo()

@test Base.showable(MIME"text/plain"(), foo)
@test sprint_plain(foo) == "Foo()"

function Base.show(io::IO, mime::MIME"text/plain", foo::Foo)
    printstyled(io, "Foo", color = :light_green)
    print(io, "()")
end

@test string(foo) == "Foo()"
@test sprint(show, foo) == "Foo()"
@test sprint_plain(foo)   == "Foo()"
@test sprint_colored(foo) == "\e[92mFoo\e[39m()"

@test @sprint_plain(foo)                                        == "Foo()"
@test @sprint_plain(print(stdout, foo))                         == "Foo()"
@test @sprint_plain(Base.show(stdout, MIME("text/plain"), foo)) == "Foo()"

@test @sprint_colored(foo)                                        == "\e[92mFoo\e[39m()"
@test @sprint_colored(print(stdout, foo))                         == "Foo()"
@test @sprint_colored(Base.show(stdout, MIME("text/plain"), foo)) == "\e[92mFoo\e[39m()"


@test "π" == string(pi) ==
             sprint(show, pi)
@test "π = 3.1415926535897..." == sprint_plain(pi) ==
                                  sprint_colored(pi)
for x in (pi, [1 2 3],
          :, sprint, Base.show)
    @test string(x) == sprint(show, x) != sprint_plain(x) == sprint_colored(x)
end

for x in (:foo, "foo")
    @test string(x) != sprint(show, x) == sprint_plain(x) == sprint_colored(x)
end

for x in (Foo,
          nothing, true, 1:3, 1:2:3,
          Int64, String, Tuple{}, Union{Int}, T where T,
          (), (1, 2, 3),
          (;), (; a = 1),
          [],
         )
    @test string(x) == sprint(show, x) == sprint_plain(x) == sprint_colored(x)
end

if VERSION >= v"1.8"
    array2 = eval(Meta.parse("""[;;]"""))  # [;;]
    array3 = eval(Meta.parse("""[;;;]""")) # [;;;]
    for x in (array2, array3)
        @test string(x) == sprint(show, x) != sprint_plain(x) == sprint_colored(x)
    end
    x = eval(Meta.parse("""[;]"""))  # [;]
    @test string(x) == sprint(show, x) == sprint_plain(x) == sprint_colored(x)
end

@test !(Base.showable(MIME"text/html"(), foo))
@test_throws MethodError sprint_html(foo)

function Base.show(io::IO, mime::MIME"text/html", foo::Foo)
    Base.show(io, MIME"text/plain"(), foo)
end

@test Base.showable(MIME"text/html"(), foo)
@test sprint_html(foo) == "Foo()"

end # module test_jive_sprints
