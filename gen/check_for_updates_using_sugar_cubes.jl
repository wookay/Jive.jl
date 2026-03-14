# check_for_updates_using_sugar_cubes.jl
#
# ~/.julia/dev/Jive main✔   ln -s  JULIA_SOURCE_PATH  sources

using Test
using SugarCubes: code_block_with, has_diff
# https://github.com/wookay/SugarCubes.jl

function check_the_code_block_diff(src_path::String,
                                   src_signature::Expr,
                                   dest_path::String,
                                   dest_signature::Expr ;
                                   skip_lines = (src = Int[], dest = Int[]))
    printstyled(stdout, "check_the_code_block_diff", color = :blue)
    print(stdout, " ", basename(src_path), " ")
    src_filepath = normpath(@__DIR__, "..", src_path)
    dest_filepath = normpath(@__DIR__, "..", dest_path)
    @test isfile(src_filepath)
    @test isfile(dest_filepath)
    src_block = code_block_with(; filepath = src_filepath, signature = src_signature)
    (depth, kind, sig) = src_block.signature.layers[end]
    printstyled(stdout, sig.args[1], color = :cyan)
    dest_block = code_block_with(; filepath = dest_filepath, signature = dest_signature)
    @test has_diff(src_block, dest_block; skip_lines) === false
    println(stdout)
end

if VERSION >= v"1.14-DEV"
check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test macro test(ex, kws...) end end),
    "ext/TestExt.jl",
    :(module TestExt if VERSION >= v"1.14.0-DEV.1453" elseif VERSION >= v"1.11" macro test(ex, kws::Expr...) end end end) ;
    skip_lines = (src = [-6], dest = [-6])
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function do_test(result::ExecutionResult, @nospecialize(orig_expr), context=nothing) end end),
    "ext/TestExt.jl",
    :(module TestExt if VERSION >= v"1.14.0-DEV.1453" elseif VERSION >= v"1.11" function do_test_ext(result::ExecutionResult, @nospecialize(orig_expr), context=nothing) end end end) ;
    skip_lines = (src = [-4], dest = collect(-8:-4))
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function do_broken_test(result::ExecutionResult, @nospecialize(orig_expr), context=nothing) end end),
    "ext/TestExt.jl",
    :(module TestExt if VERSION >= v"1.14.0-DEV.1453" elseif VERSION >= v"1.11" function do_broken_test_ext(result::ExecutionResult, @nospecialize(orig_expr), context=nothing) end end end)
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function Base.show(io::IO, t::Fail) end end),
    "ext/TestExt.jl",
    :(module TestExt if VERSION >= v"1.14.0-DEV.1453" elseif VERSION >= v"1.11" function Base.show(io::Base.TTY, t::Fail) end end end)
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function testset_context(args, ex, source) end end),
    "src/compat.jl",
    :(if VERSION >= v"1.9.0-DEV.1055" else function _testset_context(args, ex, source) end end),
    skip_lines = (src = [-4], dest = collect(-6:-4))
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function testset_forloop(args, testloop, source) end end),
    "src/compat.jl",
    :(if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" function _testset_forloop(args, testloop, source) end end)
)

check_the_code_block_diff(
    "sources/stdlib/Test/src/Test.jl",
    :(module Test function testset_beginend_call(args, tests, source) end end),
    "src/compat.jl",
    :(if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336" function _testset_beginend_call(args, tests, source) end end)
)

check_the_code_block_diff(
    "sources/base/env.jl",
    :(function parse_bool_env(name::String, val::String = ENV[name]; throw::Bool=false) end),
    "src/compat.jl",
    :(if VERSION >= v"1.11.0-DEV.1432" else function parse_bool_env(name::String, val::String = ENV[name]; throw::Bool=false)::Union{Nothing, Bool} end end)
)

check_the_code_block_diff(
    "sources/base/env.jl",
    :(function get_bool_env(f_default::Callable, name::String; kwargs...) end),
    "src/compat.jl",
    :(if VERSION >= v"1.11.0-DEV.1432" else function compat_get_bool_env(f_default::Callable, name::String; kwargs...)::Union{Nothing, Bool} end end)
)

check_the_code_block_diff(
    "sources/base/errorshow.jl",
    :(function show_processed_backtrace(io::IO, trace::Vector, num_frames::Int, repeated_cycles::Vector{NTuple{3, Int}}, max_nested_cycles::Int; print_linebreaks::Bool, prefix = nothing) end),
    "src/errorshow.jl",
    :(if VERSION >= v"1.13.0-DEV.927" function show_processed_backtrace(io::IOContext, trace::Vector, num_frames::Int, repeated_cycles::Vector{NTuple{3, Int}}, max_nested_cycles::Int; print_linebreaks::Bool, prefix = nothing) end end)
)
end # if
