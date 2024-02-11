# This file is a part of Julia. License is MIT: https://julialang.org/license

"""
    struct TermCapability

Specification of a single terminal capability.

!!! warning
  This is not part of the public API, and thus subject to change without notice.

# Fields

- `name::Symbol`: The name of the terminfo capability variable
- `capname::Symbol`: The *Cap-name* of the capability
- `description::String`: A description of the purpose of the capability

See also: `TermInfo`, `TERM_FLAGS`, `TERM_NUMBERS`, and `TERM_STRINGS`.
"""
struct TermCapability
    name::Symbol
    capname::Symbol
    description::String
end

"""
    struct TermInfoRaw

A structured representation of a terminfo file, without any knowledge of
particular capabilities, solely based on `term(5)`.

!!! warning
  The structure of this type is not part of the public API, and thus subject to
  change without notice.

# Fields

- `names::Vector{String}`: The names this terminal is known by.
- `flags::BitVector`: An (ordered) list of flag values.
- `numbers::Union{Vector{Int16}, Vector{Int32}}`: An (ordered) list of  number
  values. A value of `typemax(eltype(numbers))` is used to skip over unspecified
  capabilities while ensuring value indices are correct.
- `strings::Vector{Union{String, Nothing}}`: An ordered list of  string values.
  A value of `nothing` is used to skip over unspecified capabilities while
  ensuring value indices are correct.
- `extended::Union{Nothing, Dict{Symbol, Union{Bool, Int, String}}}`: Should an
  extended info section exist, this gives the entire extended info as a
  dictionary. Otherwise `nothing`.

See also: `TermInfo` and `TermCapability`.
"""
struct TermInfoRaw
    names::Vector{String}
    flags::BitVector
    numbers::Vector{Int}
    strings::Vector{Union{String, Nothing}}
    extended::Union{Nothing, Dict{Symbol, Union{Bool, Int, String, Nothing}}}
end

"""
    struct TermInfo

A parsed terminfo paired with capability information.

!!! warning
  The structure of this type is not part of the public API, and thus subject to
  change without notice.

# Fields

- `names::Vector{String}`: The names this terminal is known by.
- `flags::Int`: The number of flags specified.
- `numbers::BitVector`: A mask indicating which of `TERM_NUMBERS` have been
  specified.
- `strings::BitVector`: A mask indicating which of `TERM_STRINGS` have been
  specified.
- `extensions::Vector{Symbol}`: A list of extended capability variable names.
- `capabilities::Dict{Symbol, Union{Bool, Int, String}}`: The capability values
  themselves.

See also: `TermInfoRaw` and `TermCapability`.
"""
struct TermInfo
    names::Vector{String}
    flags::Dict{Symbol, Bool}
    numbers::Dict{Symbol, Int}
    strings::Dict{Symbol, String}
    extensions::Union{Nothing, Set{Symbol}}
    aliases::Dict{Symbol, Symbol}
end

TermInfo() = TermInfo([], Dict(), Dict(), Dict(), nothing, Dict())

Base.get(ti::TermInfo, key::Symbol, default::Bool) =
    get(ti.flags,   get(ti.aliases, key, key), default)
Base.get(ti::TermInfo, key::Symbol, default::Int) =
    get(ti.numbers, get(ti.aliases, key, key), default)
Base.get(ti::TermInfo, key::Symbol, default::String) =
    get(ti.strings, get(ti.aliases, key, key), default)

Base.haskey(ti::TermInfo, key::Symbol) =
    haskey(ti.flags, key) || haskey(ti.numbers, key) || haskey(ti.strings, key) || haskey(ti.aliases, key)

function Base.getindex(ti::TermInfo, key::Symbol)
    haskey(ti.flags, key) && return ti.flags[key]
    haskey(ti.numbers, key) && return ti.numbers[key]
    haskey(ti.strings, key) && return ti.strings[key]
    haskey(ti.aliases, key) && return getindex(ti, ti.aliases[key])
    throw(KeyError(key))
end

Base.keys(ti::TermInfo) =
    keys(ti.flags) ∪ keys(ti.numbers) ∪ keys(ti.strings) ∪ keys(ti.aliases)

function Base.show(io::IO, ::MIME"text/plain", ti::TermInfo)
    print(io, "TermInfo(", ti.names, "; ", length(ti.flags), " flags, ",
          length(ti.numbers), " numbers, ", length(ti.strings), " strings")
    !isnothing(ti.extensions) &&
        print(io, ", ", length(ti.extensions), " extended capabilities")
    print(io, ')')
end
