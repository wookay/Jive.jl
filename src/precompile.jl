# module Jive

# julia --trace-compile-timing --trace-compile=stderr --compiled-modules=yes  runtests.jl

# Jive.runtests
#= 2103.2 ms =# precompile(Tuple{typeof(Jive.runtests), String})
if VERSION >= v"1.9.0-DEV.1598" # Core.kwcall - julia commit ccb0a02dc6
#=   34.2 ms =# precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:targets, :node1, :skip), Tuple{String, Array{String, 1}, Array{String, 1}}}, typeof(Jive.runtests), String})
#=    6.4 ms =# precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:targets, :enable_distributed, :verbose), Tuple{Array{String, 1}, Bool, Bool}}, typeof(Jive.runtests), String})
#=    7.1 ms =# precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:targets, :enable_distributed, :into, :verbose), Tuple{Array{String, 1}, Bool, Nothing, Bool}}, typeof(Jive.runtests), String})
#=   24.5 ms =# precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:targets, :enable_distributed, :into, :verbose, :failfast), Tuple{String, Bool, Module, Bool, Bool}}, typeof(Jive.runtests), String})
end # if

# Jive.Total
#=    6.4 ms =# precompile(Tuple{typeof(Base.getproperty), NamedTuple{(:value, :output, :error, :backtrace), Tuple{Jive.Total, String, Bool, Array{Ptr{Nothing}, 1}}}, Symbol})

# compat.jl
#=  116.5 ms =# precompile(Tuple{typeof(Jive.compat_default_testset), Expr, Vararg{Expr}})
#=    7.2 ms =# precompile(Tuple{typeof(Jive.compat_default_testset), Expr})
# compat.jl - Jive._testset_beginend_call
if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336"
#=   54.8 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{String, Expr, Expr}, Expr, LineNumberNode})
#=   17.7 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{String, Expr}, Expr, LineNumberNode})
#=   44.9 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{Expr, Expr}, Expr, LineNumberNode})
#=   33.9 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{Expr}, Expr, LineNumberNode})
end

# Test - recompile
#=   78.2 ms =# precompile(Tuple{typeof(Test.do_test_throws), Test.ExecutionResult, Vararg{Any, 4}}) # recompile
#=   20.8 ms =# precompile(Tuple{typeof(Test.finish), Test.DefaultTestSet}) # recompile

# Jive.delete
#=   12.2 ms =# precompile(Tuple{typeof(Jive.delete), Any})

# @time_expr
#=   43.6 ms =# precompile(Tuple{typeof(Jive.remove_linenums_macrocall!), Any})

# @useinside
#=    8.8 ms =# precompile(Tuple{typeof(Jive._useinsde), Module, Expr})

# @skip
#=    3.3 ms =# precompile(Tuple{typeof(Jive.is_enabled_jive_skip_macro)})

# module Jive
