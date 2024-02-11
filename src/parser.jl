# This file is a part of Julia. License is MIT: https://julialang.org/license

# Since this code is in the startup-path, we go to some effort to
# be easier on the compiler, such as using `map` over broadcasting.

function Base.read(data::IO, ::Type{TermInfoRaw})
    # Parse according to `term(5)`
    # Header
    magic = read(data, UInt16) |> ltoh
    NumInt = if magic == 0o0432
        Int16
    elseif magic == 0o01036
        Int32
    else
        throw(ArgumentError("Terminfo data did not start with the magic number 0o0432 or 0o01036"))
    end
    name_bytes, flag_bytes, numbers_count, string_count, table_bytes =
        Base.@ntuple 5 _->read(data, Int16) |> ltoh
    # Terminal Names
    term_names = map(String, split(String(read(data, name_bytes - 1)), '|'))
    0x00 == read(data, UInt8) ||
        throw(ArgumentError("Terminfo data did not contain a null byte after the terminal names section"))
    # Boolean Flags
    flags = map(==(0x01), read(data, flag_bytes))
    if position(data) % 2 != 0
        0x00 == read(data, UInt8) ||
            throw(ArgumentError("Terminfo did not contain a null byte after the flag section, expected to position the start of the numbers section on an even byte"))
    end
    # Numbers, Strings, Table
    numbers = map(Int ∘ ltoh, reinterpret(NumInt, read(data, numbers_count * sizeof(NumInt))))
    string_indices = map(ltoh, reinterpret(Int16, read(data, string_count * sizeof(Int16))))
    strings_table = read(data, table_bytes)
    strings = _terminfo_read_strings(strings_table, string_indices)
    TermInfoRaw(term_names, flags, numbers, strings,
                if !eof(data) extendedterminfo(data, NumInt) end)
end

"""
    extendedterminfo(data::IO; NumInt::Union{Type{Int16}, Type{Int32}})

Read an extended terminfo section from `data`, with `NumInt` as the numbers type.

This will accept any terminfo content that conforms with `term(5)`.

See also: `read(::IO, ::Type{TermInfoRaw})`
"""
function extendedterminfo(data::IO, NumInt::Union{Type{Int16}, Type{Int32}})
    # Extended info
    if position(data) % 2 != 0
        0x00 == read(data, UInt8) ||
            throw(ArgumentError("Terminfo did not contain a null byte before the extended section; expected to position the start on an even byte"))
    end
    # Extended header
    flag_bytes, numbers_count, string_count, table_count, table_bytes =
        Base.@ntuple 5 _->read(data, Int16) |> ltoh
    # Extended flags/numbers/strings
    flags = map(==(0x01), read(data, flag_bytes))
    if flag_bytes % 2 != 0
        0x00 == read(data, UInt8) ||
            throw(ArgumentError("Terminfo did not contain a null byte after the extended flag section; expected to position the start of the numbers section on an even byte"))
    end
    numbers = map(Int ∘ ltoh, reinterpret(NumInt, read(data, numbers_count * sizeof(NumInt))))
    table_indices = map(ltoh, reinterpret(Int16, read(data, table_count * sizeof(Int16))))
    table_data = read(data, table_bytes)
    strings = _terminfo_read_strings(table_data, table_indices[1:string_count])
    table_halfoffset = Int16(get(table_indices, string_count, 0) +
        ncodeunits(something(get(strings, length(strings), ""), "")) + 1)
    for index in string_count+1:lastindex(table_indices)
        table_indices[index] += table_halfoffset
    end
    labels = map(Symbol, _terminfo_read_strings(table_data, table_indices[string_count+1:end]))
    Dict{Symbol, Union{Bool, Int, String, Nothing}}(
        zip(labels, Iterators.flatten((flags, numbers, strings))))
end

"""
    _terminfo_read_strings(table::Vector{UInt8}, indices::Vector{Int16})

From `table`, read a string starting at each position in `indices`. Each string
must be null-terminated. Should an index be -1 or -2, `nothing` is given instead
of a string.
"""
function _terminfo_read_strings(table::Vector{UInt8}, indices::Vector{Int16})
    strings = Vector{Union{Nothing, String}}(undef, length(indices))
    map!(strings, indices) do idx
        if idx >= 0
            len = findfirst(==(0x00), view(table, 1+idx:length(table)))
            !isnothing(len) ||
                throw(ArgumentError("Terminfo table entry @$idx does not terminate with a null byte"))
            String(table[1+idx:idx+len-1])
        elseif idx ∈ (-1, -2)
        else
            throw(ArgumentError("Terminfo table index is invalid: -2 ≰ $idx"))
        end
    end
    strings
end

"""
    TermInfo(raw::TermInfoRaw)

Construct a `TermInfo` from `raw`, using known terminal capabilities (as of
NCurses 6.3, see `TERM_FLAGS`, `TERM_NUMBERS`, and `TERM_STRINGS`).
"""
function TermInfo(raw::TermInfoRaw)
    capabilities = Dict{Symbol, Union{Bool, Int, String}}()
    sizehint!(capabilities, 2 * (length(raw.flags) + length(raw.numbers) + length(raw.strings)))
    flags = Dict{Symbol, Bool}()
    numbers = Dict{Symbol, Int}()
    strings = Dict{Symbol, String}()
    aliases = Dict{Symbol, Symbol}()
    extensions = nothing
    for (flag, value) in zip(TERM_FLAGS, raw.flags)
        flags[flag.name] = value
        aliases[flag.capname] = flag.name
    end
    for (num, value) in zip(TERM_NUMBERS, raw.numbers)
        numbers[num.name] = Int(value)
        aliases[num.capname] = num.name
    end
    for (str, value) in zip(TERM_STRINGS, raw.strings)
        if !isnothing(value)
            strings[str.name] = value
            aliases[str.capname] = str.name
        end
    end
    if !isnothing(raw.extended)
        extensions = Set{Symbol}()
        longalias(key, value) = first(get(TERM_USER, (typeof(value), key), (nothing, "")))
        for (short, value) in raw.extended
            long = longalias(short, value)
            key = something(long, short)
            push!(extensions, key)
            if value isa Bool
                flags[key] = value
            elseif value isa Int
                numbers[key] = value
            elseif value isa String
                strings[key] = value
            end
            if !isnothing(long)
                aliases[short] = long
            end
        end
    end
    TermInfo(raw.names, flags, numbers, strings, extensions, aliases)
end
