var documenterSearchIndex = {"docs":
[{"location":"#APTDecoder","page":"APTDecoder","title":"APTDecoder","text":"","category":"section"},{"location":"","page":"APTDecoder","title":"APTDecoder","text":"APTDecoder Julia package repo.","category":"page"},{"location":"","page":"APTDecoder","title":"APTDecoder","text":"Modules = [APTDecoder]","category":"page"},{"location":"#APTDecoder.decode-Tuple{Any, Any}","page":"APTDecoder","title":"APTDecoder.decode","text":"datatime, (channelA,channelB), data = decode(y,Fs)\n\nDecode the APT image in a time series y defined at a frequency Fs (in Hz). datatime is the time in seconds counting from the beginning of the recording. channelA and channelB are arrays representing the data from the two different channels (A and B). data is raw data as an array including channel A and B, as well sync markers and telemetry.\n\nExample\n\nusing FileIO\nusing APTDecoder\n\nwavname = \"gqrx_20190804_141523_137100000.wav\"\ny,Fs,nbits,opt = load(wavname)\ndatatime,(channelA,channelB),data = APTDecode.decode(y,Fs)\n\n\n\n\n\n\n","category":"method"},{"location":"#APTDecoder.georeference-NTuple{4, Any}","page":"APTDecoder","title":"APTDecoder.georeference","text":"plon,plat,data = georeference(pngname,satellite_name,channel)\n\nCompute longitude and latitude of the NOAA APT satellite image in pngname using the orbit of the satellite with the name satellite_name (generally \"NOAA 15\", \"NOAA 18\", \"NOAA 19\"). The file name pngname should  have the followng structure: string_date_time_frequency.png like gqrx_20190811_075102_137620000.png. Date and time of the file name are in UTC.\n\nExample:\n\nsatellite_name = \"NOAA 15\"\npngname = \"gqrx_20190811_075102_137620000.png\";\nAPTDecoder.georeference(pngname,satellite_name)\n\n\n\n\n\n","category":"method"},{"location":"#APTDecoder.get_tle-Tuple{Any}","page":"APTDecoder","title":"APTDecoder.get_tle","text":"tles = get_tle(:weather)\n\nLoad the two-line elements (TLEs) data from https://www.celestrak.com for weather satellites. \n\n\n\n\n\n","category":"method"},{"location":"#APTDecoder.makeplots-Tuple{Any, Any}","page":"APTDecoder","title":"APTDecoder.makeplots","text":"makeplots(wavname,satellite_name)\n\nDecodes the APT signal in wavname as recorded by gqrx using wide FM-mono demodulation. The file name wavname should  have the followng structure: string_date_time_frequency.wav like gqrx_20190811_075102_137620000.wav. Date and time of the file name are in UTC (not local time). satellite_name is the name of the satellite (generally \"NOAA 15\", \"NOAA 18\", \"NOAA 19\").\n\nExample:\n\nimport APTDecoder\n\nwavname = \"gqrx_20190825_182745_137620000.wav\"\nAPTDecoder.makeplots(wavname,\"NOAA 15\")\n\n\n\n\n\n","category":"method"}]
}
