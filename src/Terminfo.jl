# This file is a part of Julia. License is MIT: https://julialang.org/license

module Terminfo

export TermInfo, TermInfoRaw

include("types.jl")
include("data.jl")

"""
The terminfo of the current terminal.
"""
current_terminfo::TermInfo = TermInfo()

include("parser.jl")
include("loading.jl")
include("truecolor.jl")
include("prettyprinter.jl")

function __init__()
    global current_terminfo = load_terminfo()
end

end
