#!/usr/bin/env julia

using ArgParse
using FileIO
using Statistics
import APTDecoder
using PyPlot


s = ArgParseSettings()
@add_arg_table s begin
    "--satellite", "-s"
        help = "the satellite name ( \"NOAA 15\",  \"NOAA 18\",  \"NOAA 19\")"
        required = true
    "--starttime", "-t"
        help = "start time of the capture in UTC. It can be deduced from the file name, if it has the structure like gqrx_20190811_075102_137620000.png."
    "--output-prefix"
        help = "an option without argument, i.e. a flag"
    "wav"
        help = "a positional argument"
        required = true
end

parsed_args = parse_args(ARGS, s)

@show parsed_args
wavname = parsed_args["wav"]
satellite_name = parsed_args["satellite"]

# missing paramter have a value nothing
kwargs = filter(kv -> (kv[2] != nothing) && !(kv[1] ∈ ["wav","satellite"]),parsed_args)

APTDecoder.makeplots(wavname,satellite_name,kwargs...)
