using Documenter, APTDecoder

makedocs(modules = [APTDecoder], sitename = "APTDecoder.jl")

deploydocs(
    repo = "github.com/Alexander-Barth/APTDecoder.jl.git",
)
