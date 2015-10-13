# This file is a part of Julia. License is MIT: http://julialang.org/license

using Base.Test

function runtests(name)
    @printf("     \033[1m*\033[0m \033[31m%-21s\033[0m", name)
    tt = @elapsed include("$name.jl")
    @printf(" in %6.2f seconds, rss %7.2f MB\n", tt, Sys.get_rusage().ru_maxrss / 2^20)

    nothing
end

# looking in . messes things up badly
filter!(x->x!=".", LOAD_PATH)
