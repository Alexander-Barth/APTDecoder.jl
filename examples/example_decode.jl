import APTDecoder
import SatelliteToolbox
using Statistics
using PyPlot
using WAV

wavname = "/home/abarth/src/APTDecoder/test.wav"
wavname = "/mnt/data1/abarth/Backup/abarth/testapt/gqrx_20180715_150114_137100000.wav"

#wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190804_141523_137100000.wav"
wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190814_192855_137917500.wav"
wavname = "gqrx_20190804_141523_137100000.wav"
wavname = "gqrx_20190823_173900_137620000.wav"

satellite_name = "NOAA 19"
satellite_name = "NOAA 15"

# satellite orbit information (TLE)
tles = SatelliteToolbox.read_tle("weather-20190823.txt")

y,Fs,nbits,opt = wavread(wavname)

datatime,(channelA,channelB),data = APTDecoder.decode(y,Fs)

vmin,vmax = quantile(view(data,:),[0.01,0.99])
data[data .> vmax] .= vmax;
data[data .< vmin] .= vmin;

#=
cmap = "RdYlBu_r"
subplot(1,2,1);
imshow(channelA, aspect="auto", cmap=cmap); colorbar();
title("Channel A")

subplot(1,2,2);
imshow(channelB, aspect="auto", cmap=cmap); colorbar();
title("Channel B")
=#


figure("APTDecoder")
cmap = "RdYlBu_r"
#subplot(2,1,1);
#pcolormesh(reverse(reverse(data,dims=1),dims=2))
#colorbar()
subplot(2,1,1);
imshow(reverse(reverse(data,dims=1),dims=2), aspect="auto", cmap=cmap);
title("Raw data")

starttime = APTDecoder.starttimename(wavname)

# TLEs are downloaded if omited
Alon,Alat,Adata = APTDecoder.georeference(channelA,satellite_name,datatime,starttime; tles=tles)
subplot(2,2,3)
APTDecoder.plot(Alon,Alat,Adata)
title("Channel A")

Blon,Blat,Bdata = APTDecoder.georeference(channelB,satellite_name,datatime,starttime; tles=tles)
subplot(2,2,4)
#figure("Channel B - geo")
APTDecoder.plot(Blon,Blat,Bdata)
title("Channel B")


#=
starttime = APTDecoder.starttimename(wavname)

# TLEs are downloaded if omited
Alon,Alat,Adata = APTDecoder.georeference(channelA,satellite_name,datatime,starttime; tles=tles)
figure("Channel A - geo")
APTDecoder.plot(Alon,Alat,Adata)

Blon,Blat,Bdata = APTDecoder.georeference(channelB,satellite_name,datatime,starttime; tles=tles)
figure("Channel B - geo")
APTDecoder.plot(Blon,Blat,Bdata)
=#
