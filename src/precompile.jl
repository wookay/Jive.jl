# module Jive

# julia --trace-compile-timing --trace-compile=stderr --compiled-modules=yes  runtests.jl

# Jive.runtests
#= 2103.2 ms =# precompile(Tuple{typeof(Jive.runtests), String})

# Jive._testset_beginend_call
if v"1.13.0-DEV.731" > VERSION >= v"1.11.0-DEV.336"
#=   54.8 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{String, Expr, Expr}, Expr, LineNumberNode})
#=   17.7 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{String, Expr}, Expr, LineNumberNode})
#=   44.9 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{Expr, Expr}, Expr, LineNumberNode})
#=   33.9 ms =# precompile(Tuple{typeof(Jive._testset_beginend_call), Tuple{Expr}, Expr, LineNumberNode})
end

# Jive.JiveTestSet
if VERSION >= v"1.13.0-DEV.1044" # julia commit bb368512880ca6cf051a91993c9c5bb4a8d3b7d0
else
#=   14.6 ms =# precompile(Tuple{typeof(Test.push_testset), Jive.JiveTestSet})
end
#=    7.3 ms =# precompile(Tuple{typeof(Base.push!), Array{Test.AbstractTestSet, 1}, Jive.JiveTestSet})
#=    7.5 ms =# precompile(Tuple{Type{Jive.JiveTestSet}, String})

if VERSION >= v"1.12.0-DEV.1812" # julia commit 6136893eeed0c3559263a5aa465b630d2c7dc821
#=    2.6 ms =# precompile(Tuple{typeof(Test.get_rng), Jive.JiveTestSet})
#=    3.3 ms =# precompile(Tuple{typeof(Test.set_rng!), Jive.JiveTestSet, Random.AbstractRNG})
end

# Test.record
#=    2.9 ms =# precompile(Tuple{typeof(Test.record), Jive.JiveTestSet, Jive.JiveTestSet})
#=    3.8 ms =# precompile(Tuple{typeof(Test.record), Jive.JiveTestSet, Test.Pass})
#=    4.2 ms =# precompile(Tuple{typeof(Test.record), Jive.JiveTestSet, Test.Broken})

# Test.finish
#=   16.4 ms =# precompile(Tuple{typeof(Test.finish), Jive.JiveTestSet}) # recompile

# Jive.delete
#=   12.2 ms =# precompile(Tuple{typeof(Jive.delete), Any})

# @time_expr
#=   43.6 ms =# precompile(Tuple{typeof(Jive.remove_linenums_macrocall!), Any})

# @useinside
#=    8.8 ms =# precompile(Tuple{typeof(Jive._useinsde), Module, Expr})

# @skip
#=    3.3 ms =# precompile(Tuple{typeof(Jive.is_enabled_jive_skip_macro)})

# module Jive
