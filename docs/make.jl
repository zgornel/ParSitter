using Pkg
Pkg.add("Documenter")
Pkg.add("DocumenterMermaid")

using Documenter
using DocumenterMermaid
using ParSitter
using AbstractTrees

# Make src directory available
push!(LOAD_PATH, "../src/")

# Make documentation
makedocs(
    #modules = [ParSitter],
    format = Documenter.HTML(),
    sitename = "ParSitter",
    authors = "Corneliu Cofaru",
    clean = true,
    debug = true,
    pages = [
        "Introduction" => "index.md",
        "Usage examples" => "examples.md",
        "API Reference" => "api.md",
    ],
    repo = "github.com:zgornel/ParSitter.git",
)

# Deploy documentation
deploydocs(
    #remotes=nothing,
    repo = "github.com/zgornel/ParSitter.git",
    target = "build",
    deps = nothing,
    make = nothing
)
