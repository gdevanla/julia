# This file is a part of Julia. License is MIT: http://julialang.org/license

include("choosetests.jl")
tests, net_on = choosetests(ARGS)
tests = unique(tests)

# Base.compile only works from node 1, so compile test is handled specially
compile_test = "compile" in tests
if compile_test
    splice!(tests, findfirst(tests, "compile"))
end

cd(dirname(@__FILE__)) do
    n = 1
    if net_on
        n = min(8, CPU_CORES, length(tests))
        n > 1 && addprocs(n; exeflags=`--check-bounds=yes --depwarn=error`)
        blas_set_num_threads(1)
    end

    @everywhere include("testdefs.jl")

    const max_worker_rss = parse(Int, get(ENV, "JULIA_TEST_MAXRSS_MB", "200"))
    @sync begin
        for p in workers()
            @async begin
                while length(tests) > 0
                    test = shift!(tests)
                    resp = remotecall_fetch(t -> (runtests(t); Sys.maxrss()), p, test)

                    if isa(resp, Integer)
                        if resp > max_worker_rss * 2^20
                            rmprocs(p, waitfor=0.5)
                            p = addprocs(1; exeflags=`--check-bounds=yes --depwarn=error`)[1]
                            remotecall_fetch(()->include("testdefs.jl"), p)
                        end
                    elseif isa(resp, Exception)
                        rethrow(resp)
                    else
                        error("Unknown error $resp while executing test $test")
                    end
                end
            end
        end
    end

    if compile_test
        n > 1 && print("\tFrom worker 1:\t")
        runtests("compile")
    end

    @unix_only n > 1 && rmprocs(workers(), waitfor=5.0)
    println("    \033[32;1mSUCCESS\033[0m")
end
