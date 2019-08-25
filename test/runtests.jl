import APTDecoder
using Test


wavname = download("https://archive.org/download/gqrx_20190825_182745_137620000/gqrx_20190825_182745_137620000.wav")
APTDecoder.makeplots(wavname,"NOAA 15")

@test 1 == 1
