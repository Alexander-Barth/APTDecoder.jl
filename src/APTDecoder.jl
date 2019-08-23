module APTDecoder

using Printf
using Dates
using LinearAlgebra
using SatelliteToolbox
using PyPlot
using CodecZlib
using RemoteFiles
import DSP
using Statistics
using WAV

scans_per_seconds = 2

# https://web.archive.org/web/20190814072342/https://noaa-apt.mbernardi.com.ar/how-it-works.html
# frequency ratio is 5/4
sync_frequency = (1040., # channel A
                  832.)   # channel B



include("GeoMapping.jl")
include("georef.jl")
include("decode.jl")
include("data.jl")
include("plot.jl")


end # module
