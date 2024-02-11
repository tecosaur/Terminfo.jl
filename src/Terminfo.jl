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

# if Base.generating_output()
#     include("precompile.jl")
# end

end
