using Documenter
using APTDecoder

makedocs(
    format = Documenter.HTML(),
    modules = [APTDecoder],
    sitename = "APTDecoder",
    pages = [
        "index.md"]
)

# Documenter can also automatically deploy documentation to gh-pages.
# See "Hosting Documentation" and deploydocs() in the Documenter manual
# for more information.

deploydocs(
    repo = "github.com/Alexander-Barth/APTDecoder.jl.git",
    target = "build"
)
