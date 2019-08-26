import APTDecoder
using Test


wavname = "gqrx_20190825_182745_137620000.wav"
download("https://archive.org/download/gqrx_20190825_182745_137620000/gqrx_20190825_182745_137620000.wav",wavname)
APTDecoder.makeplots(wavname,"NOAA 15")

@test isfile(replace(wavname,r"\.wav$" => "_raw.png"))
