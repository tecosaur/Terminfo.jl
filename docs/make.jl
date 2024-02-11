using Terminfo
using Documenter

DocMeta.setdocmeta!(Terminfo, :DocTestSetup, :(using Terminfo); recursive=true)

makedocs(;
    modules = [Terminfo],
    sitename = "Terminfo",
    authors = "tecosaur <contact@tecosaur.net> and contributors",
    repo = "https://github.com/JuliaLang/Terminfo.jl/blob/{commit}{path}#{line}",
    format = Documenter.HTML(),
    pages = [
        "Terminfo" => "index.md",
    ],
    warnonly = [:cross_references],
)

deploydocs(repo="github.com/JuliaLang/Terminfo.jl")
