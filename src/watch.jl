# module Jive

using FileWatching

const watched_folders = Dict{String, Tuple{FolderMonitor,Task}}()

"""
    watch(callback::Function, dir::String; targets=ARGS, sources::Union{Vector{Any},Vector{String}}=[])

watch the folders.
"""
function watch(callback::Function, dir::String; targets=ARGS, sources::Union{Vector{Any},Vector{String}}=[])
    (all_files, start_idx) = get_all_files(dir, [], targets)
    for src in sources
        for (root, dirs, files) in walkdir(isfile(src) ? dirname(src) : src)
            for filename in files
                !endswith(filename, ".jl") && continue
                subpath = path_separator_to_slash(relpath(normpath(root, filename), dir))
                push!(all_files, subpath)
            end
        end
    end

    function run_callback(cb, path)
        local oldstderr = stderr
        local errread, errwrite, errstream
        try
            (errread, errwrite) = redirect_stderr()
            cb(path)
        catch err
            @info :watch_catch err
        finally
            errstream = @async read(errread, String)
            redirect_stderr(oldstderr)
            close(errwrite)
        end
        errmsg = fetch(errstream)
        if !isempty(errmsg)
            for line in split(errmsg, '\n')
                !startswith(line, "WARNING: replacing module test") && print(stderr, line)
            end
        end
    end

    folders = Set(dirname.(normpath.(dir, all_files)))
    for folder in folders
        fm = FolderMonitor(folder)
        loop = Task() do
            last_time = 0
            while isopen(fm.notify)
                (fname, events) = wait(fm)::Pair
                if splitext(fname)[2] == ".jl" && time() - last_time > 0.010
                    filepath = normpath(folder, fname)
                    run_callback(callback, relpath(filepath, dir))
                    last_time = time()
                end
            end
        end
        watched_folders[folder] = (fm, loop)
    end
    for (folder, (fm, loop)) in watched_folders
        schedule(loop)
    end

    printstyled("watching folders ...\n", color=:green)
    for (folder, (fm, loop)) in watched_folders
        println("  - ", relpath(folder, dir))
    end
end

"""
    Jive.stop(::typeof(watch))

stop watching folders.
"""
function stop(::typeof(watch))
    for (folder, (fm, loop)) in watched_folders
        close(fm)
    end
    empty!(watched_folders)
    println("stopped watching folders.")
end
