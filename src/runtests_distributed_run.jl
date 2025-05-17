# code from https://github.com/JuliaLang/julia/blob/master/test/runtests.jl

using .Distributed: @everywhere, RemoteException, remotecall, remotecall_fetch, myid, nworkers, rmprocs, workers

function runner(worker::Int, idx::Int, num_tests::Int, subpath::String, context::Union{Nothing,Module}, filepath::String, verbose::Bool, color::Bool)
    numbering = string(idx, /, num_tests)
    buf = IOBuffer()
    io = IOContext(buf, :color => color)
    verbose && jive_getting_on_the_floor(io, numbering, subpath, " (worker: $worker)")
    description = jive_testset_description(numbering)
    ts = JiveTestSet(description)
    jive_lets_dance(io, verbose, ts, context, filepath)
    (ts, buf)
end

function distributed_run(dir::String, tests::Vector{String}, start_idx::Int, node1::Vector{String}, context::Union{Nothing,Module}, verbose::Bool, failfast::Bool)::Total
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
    index_subpath_dict = Dict{Int,Tuple{Int,String}}()
    total = Total()
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
                        index_subpath_dict[worker] = (idx, subpath)
                        if idx < start_idx
                            numbering = string(idx, /, num_tests)
                            verbose && jive_getting_on_the_floor(io, numbering, subpath, " --")
                            continue
                        end
                        if any(x -> startswith(subpath, x), node1)
                            push!(node1_tests, (idx, subpath))
                        else
                            filepath = normpath(dir, slash_to_path_separator(subpath))
                            f = remotecall(runner, worker, worker, idx, num_tests, subpath, context, filepath, verbose, have_color())
                            (ts, buf) = fetch(f)
                            verbose && print(io, String(take!(buf)))
                            tc = jive_accumulate_testset_data(io, verbose, total, ts)
                            if failfast && got_anynonpass(tc)
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
            tc = jive_accumulate_testset_data(io, verbose, total, ts)
            failfast && got_anynonpass(tc) && break
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
                worker = result.pid # worker (remote)
                if haskey(index_subpath_dict, worker)
                    (idx, subpath) = index_subpath_dict[worker]
                    numbering = string(idx, /, num_tests)
                    verbose && jive_getting_on_the_floor(io, numbering, subpath, " (worker: $worker)")
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
    verbose && jive_report(io, total)
    return total
end
