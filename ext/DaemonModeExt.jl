module DaemonModeExt

using DaemonMode: serverReplyError, token_ok_end
import DaemonMode: serverRun

# code from DaemonMode.jl/src/DaemonMode.jl
#     function serverRun(run, sock, shared, print_stack, fname, args, reviser)
function serverRun(run::Function, sock::IO, shared::Bool, print_stack::Bool, fname::String, args::Vector, reviser::Function)
    error = false

    try
        reviser()

        if shared
            redirect_stdout(sock) do
                redirect_stderr(sock) do
                    run(Main)
                end
            end
        else
            redirect_stdout(sock) do
                redirect_stderr(sock) do
                    m = Module()
                    # Logging.global_logger(MinLevelLogger(FormatLogger(create_mylog(fname), sock), Logging.Info))

                    Base.eval(m, quote
                        eval(x) = Base.eval(@__MODULE__, x)
                        include(x) = Base.include(@__MODULE__, x)
                        ARGS = $args
                        Base.PROGRAM_FILE::String = $fname

                        struct SystemExit <: Exception
                            code::Int32
                        end
                        exit(x) = throw(SystemExit(x))
                    end)

                    out = Base.eval(m, quote
                        const stdout = IOBuffer()
                        stdout
                    end)
                    err = Base.eval(m, quote
                        const stderr = IOBuffer()
                        stderr
                    end)
                    running = true

                    try
                        task = @async begin
                            while isopen(out) && isopen(sock)
                                text = String(take!(out))
                                print(sock, text)

                                if !running
                                    close(out)
                                end
                                sleep(0.3)
                            end
                        end
                        task2 = @async begin
                            while isopen(err)  && isopen(sock)
                                text = String(take!(err))
                                print(sock, text)

                                if !running
                                    close(err)
                                end
                                sleep(0.3)
                            end
                        end
                        run(m)
                        running = false

                        # while isopen(out) && isopen(err)
                        #     println("Espero")
                        #     sleep(0.1)
                        # end
                    catch e
                        running = false
                        e_str = string(e)
                        if occursin("SystemExit", e_str)
                            # Wait for pushing messages
                            if occursin("(0)", e_str)
                                error = false
                            else
                                error = true
                            end
                        else
                            error = true
                            rethrow(e)
                        end
                    end
                    try
                        # If there is missing message I write it
                        text = String(take!(out))

                        if !isempty(text)
                            print(sock, text)
                        end
                    # Ignore possible error in output by finishing
                    catch e
                    end
                    try
                        text = String(take!(err))

                        if !isempty(text)
                            print(sock, text)
                        end
                    # Ignore possible error in error by finishing
                    catch e
                    end
                end
            end

        end

        # Return depending of error code
        if !error
            println(sock, token_ok_end)
        else
            println(sock, token_error_end)
        end

    catch e
        if print_stack
            serverReplyError(sock, e, catch_backtrace(), fname)
        else
            serverReplyError(sock, e)
        end
    end

end # function serverRun(run::Function, sock::IO, shared::Bool, print_stack::Bool, fname::String, args::Vector, reviser::Function)

end # module DaemonModeExt
