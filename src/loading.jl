# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    find_terminfo_file(term::String)

Locate the terminfo file for `term`, return `nothing` if none could be found.

The lookup policy is described in `terminfo(5)` "Fetching Compiled
Descriptions".
"""
function find_terminfo_file(term::String)
    isempty(term) && return
    chr, chrcode = string(first(term)), string(Int(first(term)), base=16)
    terminfo_dirs = if haskey(ENV, "TERMINFO")
        [ENV["TERMINFO"]]
    elseif isdir(joinpath(homedir(), ".terminfo"))
        [joinpath(homedir(), ".terminfo")]
    else
        String[]
    end
    haskey(ENV, "TERMINFO_DIRS") &&
        append!(terminfo_dirs,
                replace(split(ENV["TERMINFO_DIRS"], ':'),
                        "" => "/usr/share/terminfo"))
    Sys.isunix() &&
        push!(terminfo_dirs, "/etc/terminfo", "/lib/terminfo", "/usr/share/terminfo")
    for dir in terminfo_dirs
        if isfile(joinpath(dir, chr, term))
            return joinpath(dir, chr, term)
        elseif isfile(joinpath(dir, chrcode, term))
            return joinpath(dir, chrcode, term)
        end
    end
end

"""
    load_terminfo(term::String = get(ENV, "TERM", ""))

Load the `TermInfo` for `term`, falling back on a blank `TermInfo`.
"""
function load_terminfo(term::String = get(ENV, "TERM", ""))
    file = find_terminfo_file(term)
    isnothing(file) && return TermInfo()
    try
        TermInfo(read(file, TermInfoRaw))
    catch err
        if err isa ArgumentError || err isa IOError
            TermInfo()
        else
            rethrow()
        end
    end
end
