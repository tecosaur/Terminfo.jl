@static if VERSION <= v"1.10"
    astr(s::String, _...) = s
else
    astr(s::String, annots::Pair{Symbol, <:Any}...) =
        Base.AnnotatedString(s, map(a -> (1:ncodeunits(s), a...), annots) |> collect)
    astr(s::String, faces::Symbol...) = astr(s, map(f -> :face => f, faces)...)
end

astr(x, attrs...) = astr(string(x), attrs...)

const NONAME_STANDIN = "-"

function _formatval(io::IO, name::Symbol, capname::Symbol, val::Bool,
                    description::String; namepad::Int, cappad::Int)
    print(io, "\n ", astr("•", :bright_blue), " ", rpad(String(name), namepad),
          rpad(astr(capname, :light), cappad),
          rpad(astr(val, ifelse(val, :yellow, :grey)), 11),
          astr(description, :italic))
end

function _formatval(io::IO, name::Symbol, capname::Symbol, val::Int,
                    description::String; namepad::Int, cappad::Int)
    print(io, "\n ", astr("•", :bright_blue), " ", rpad(String(name), namepad),
          rpad(astr(capname, :light), cappad),
          ifelse(val >= 0, " ", ""),
          rpad(astr(val, :bright_magenta), 10 + (val < 0)),
          astr(description, :italic))
end

function _formatval(io::IO, name::Symbol, capname::Symbol, val::String,
                    description::String; namepad::Int, cappad::Int)
    eval = escape_string(val)
    if textwidth(eval) <= 10
        print(io, "\n ", astr("•", :bright_blue), " ", rpad(String(name), namepad),
              rpad(astr(capname, :light), cappad),
              rpad(astr(eval, :bright_green), 11),
              astr(description, :italic))
    else
        print(io, "\n ", astr("•", :bright_blue), " ", rpad(String(name), namepad),
            rpad(astr(capname, :light), cappad),
            rpad(astr("⮟", :green), 11),
            astr(description, :italic),
            "\n   ", ' '^(namepad + cappad), astr(escape_string(val), :bright_green))
    end
end

function prettyprint(io::IO, info::TermInfo, fields::Symbol...; extended::Bool=true)
    print(io, ' ', astr("TermInfo", :bold), " for ",
          join(map(n -> astr(n, :bright_cyan), info.names), ", "))
    if isempty(fields)
        fields = (:flags, :numbers, :strings)
    end
    namepad, cappad = 0, 0
    info_restructured = []
    for (category, dtype, list, field) in (
        ("Flags",   Bool,   TERM_FLAGS,   :flags),
        ("Numbers", Int,    TERM_NUMBERS, :numbers),
        ("Strings", String, TERM_STRINGS, :strings))
        field in fields || continue
        vals = getfield(info, field)
        isempty(vals) && continue
        listrel = filter(f -> haskey(vals, f.name), list)
        namepad = maximum(textwidth ∘ String ∘ (f -> f.name),    listrel, init=0) + 2
        cappad  = maximum(textwidth ∘ String ∘ (f -> f.capname), listrel, init=0) + 2
        ext = setdiff(keys(vals), map(f -> f.name, listrel), map(f -> f.capname, listrel))
        ext_data = Tuple{Symbol, Symbol, String}[]
        if extended && !isempty(ext)
            for ((type, capname), (name, description)) in collect(TERM_USER)
                type == dtype || continue
                if name in ext
                    push!(ext_data, (name, capname, description))
                elseif capname in ext
                    push!(ext_data, (Symbol(NONAME_STANDIN), capname, description))
                end
            end
            for name in setdiff(ext, map(e -> e[1], ext_data), map(e -> e[2], ext_data))
                push!(ext_data, (Symbol(NONAME_STANDIN), name, NONAME_STANDIN))
            end
            sort!(ext_data, by=e -> e[2])
        end
        namepad = max(namepad, maximum(textwidth ∘ String ∘ e -> e[1], ext_data, init=0) + 2)
        cappad  = max(cappad,  maximum(textwidth ∘ String ∘ e -> e[2], ext_data, init=0) + 2)
        push!(info_restructured, (category, listrel, ext_data))
    end
    for (category, standard, extended) in info_restructured
        print(io, "\n\n ", astr("$category ($(length(standard) + length(extended)))", :bold, :emphasis))
        !isempty(extended) && print(io, astr(", $(length(standard)) standard", :emphasis))
        for (; name, capname, description) in standard
            _formatval(io, name, capname, info[name], description; namepad, cappad)
        end
        if !isempty(extended)
            print(io, "\n ", astr("Extended $(lowercase(category)) ($(length(extended)))", :emphasis))
            for (name, capname, description) in extended
                _formatval(io, name, capname, info[capname], description; namepad, cappad)
            end
        end
    end
    print(io, '\n')
end

prettyprint(info::TermInfo, fields::Symbol...; extended::Bool=true) =
    prettyprint(stdout, info, fields...; extended)

prettyprint(fields::Symbol...; extended::Bool=true) =
    prettyprint(stdout, current_terminfo, fields...; extended)

prettyprint(termname::String, fields::Symbol...; extended::Bool=true) =
    prettyprint(stdout, load_terminfo(termname), fields...; extended)
