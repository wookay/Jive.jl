# code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl

using .Distributed: @everywhere, RemoteException, remotecall, remotecall_fetch, myid, nworkers, rmprocs, workers

function runner(worker::Int, idx::Int, num_tests::Int, subpath::String, context::Union{Nothing,Module}, filepath::String, verbose::Bool, color::Bool)
    numbering = string(idx, /, num_tests)
    buf = IOBuffer()
    io = IOContext(buf, :color => color)
    step = Step(io, numbering, subpath, " (worker: $worker)", context, filepath, verbose)
    jive_getting_on_the_floor(io, verbose, step)
    description = step.numbering
    ts = JiveTestSet(description)
    push_testset(ts)
    jive_start!(ts)
    jive_lets_dance(step)
    jive_finish!(io, verbose, :jive, ts)
    pop_testset()
    (ts, buf)
end

@generated have_color() = :(2 != Base.JLOptions().color)

function distributed_run(dir::String, tests::Vector{String}, start_idx::Int, node1::Vector{String}, context::Union{Nothing,Module}, verbose::Bool)
    io = IOContext(Core.stdout, :color => have_color())
    printstyled(io, "nworkers()", color=:cyan)
    printstyled(io, ": ", nworkers(), ", ")
    printstyled(io, "Threads.nthreads()", color=:cyan)
    printstyled(io, ": ", Threads.nthreads(), ", ")
    printstyled(io, "Sys.CPU_THREADS", color=:cyan)
    printstyled(io, ": ", Sys.CPU_THREADS)
    println(io)

    idx = 0
    num_tests = length(tests)
    env = Dict{Int,Tuple{Int,String}}()
    total_compile_time = UInt64(0)
    total_recompile_time = UInt64(0)
    total_elapsed_time = UInt64(0)
    total_anynonpass = false
    n_passes = 0
    n_fails = 0
    n_errors = 0
    n_broken = 0
    n_skipped = 0
    try
        node1_tests = []
        if isfile(normpath(dir, "Project.toml"))
            project = Base.JLOptions().project
            if project != C_NULL
                prj = unsafe_string(project)
                if prj == "@."
                    prj = ""
                end
                @everywhere @eval(using Pkg)
                @everywhere @eval(Pkg.activate($prj))
            end
        end
        @everywhere @eval(using Jive)
        stop = false
        @sync begin
            for worker in workers()
                @async begin
                    while !stop && length(tests) > 0
                        idx += 1
                        subpath = popfirst!(tests)
                        env[worker] = (idx, subpath)
                        if idx < start_idx
                            numbering = string(idx, /, num_tests)
                            step = Step(io, numbering, subpath, " --", context, "", verbose)
                            jive_getting_on_the_floor(io, verbose, step)
                            continue
                        end
                        if any(x -> startswith(subpath, x), node1)
                            push!(node1_tests, (idx, subpath))
                        else
                            filepath = normpath(dir, slash_to_path_separator(subpath))
                            f = remotecall(runner, worker, worker, idx, num_tests, subpath, context, filepath, verbose, have_color())
                            (ts, buf) = fetch(f)
                            verbose && print(io, String(take!(buf)))
                            total_compile_time += ts.compile_time
                            total_recompile_time += ts.recompile_time
                            total_elapsed_time += ts.elapsed_time
                            tc = jive_get_test_counts(ts)
                            verbose && jive_print_counts(io, ts, tc)
                            n_passes += tc.passes + tc.c_passes
                            n_fails += tc.fails + tc.c_fails
                            n_errors += tc.errors + tc.c_errors
                            n_broken += tc.broken + tc.c_broken
                            n_skipped += tc.skipped + tc.c_skipped
                            if !total_anynonpass && got_anynonpass(tc)
                                total_anynonpass = true
                            end
                            if jive_stop_on_failure && total_anynonpass
                                stop = true
                                break
                            end
                        end
                    end # while length(tests) > 0
                    if worker != 1
                        # Free up memory =)
                        rmprocs(worker, waitfor=0)
                    end
                end # @async begin
                stop && break
            end # for worker in workers()
        end # @sync begin
        worker = myid()
        for (idx, subpath) in node1_tests
            filepath = normpath(dir, slash_to_path_separator(subpath))
            f = remotecall(runner, worker, worker, idx, num_tests, subpath, context, filepath, verbose, have_color())
            (ts, buf) = fetch(f)
            verbose && print(io, String(take!(buf)))
            total_compile_time += ts.compile_time
            total_recompile_time += ts.recompile_time
            total_elapsed_time += ts.elapsed_time
            tc = jive_get_test_counts(ts)
            verbose && jive_print_counts(io, ts, tc)
            n_passes += tc.passes + tc.c_passes
            n_fails += tc.fails + tc.c_fails
            n_errors += tc.errors + tc.c_errors
            n_broken += tc.broken + tc.c_broken
            n_skipped += tc.skipped + tc.c_skipped
            if !total_anynonpass && got_anynonpass(tc)
                total_anynonpass = true
            end
            if jive_stop_on_failure && total_anynonpass
                break
            end
        end
    catch err
        print(io, "⚠️  ")
        if err isa CompositeException
            exception = first(err.exceptions)
            if exception isa CapturedException
                result = exception.ex
            elseif Symbol(typeof(exception)) === :TaskFailedException  # VERSION >= v"1.3.0-alpha.110"
                result = exception.task.result
            else
                result = nothing
            end
            if result isa RemoteException
                remote_worker = result.pid
                if haskey(env, remote_worker)
                    (idx, subpath) = env[remote_worker]
                    numbering = string(idx, /, num_tests)
                    step = Step(io, numbering, subpath, " (worker: $remote_worker)")
                    jive_getting_on_the_floor(step, verbose)
                    showerror(io, result)
                    println(io)
                end
            else
                showerror(io, exception)
                println(io)
            end
        else
            showerror(io, err)
            println(io)
        end
    finally
        GC.gc()
    end
    verbose && jive_report(io, total_compile_time, total_recompile_time, total_elapsed_time, total_anynonpass, n_passes, n_fails, n_errors, n_broken, n_skipped)
end
