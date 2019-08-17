using FileIO
using Statistics
import APTDecoder
using PyPlot

wavname = "/home/abarth/src/APTDecoder/test.wav"
wavname = "/mnt/data1/abarth/Backup/abarth/testapt/gqrx_20180715_150114_137100000.wav"

#wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190804_141523_137100000.wav"
wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190814_192855_137917500.wav"
wavname = "gqrx_20190804_141523_137100000.wav"

satellite_name = "NOAA 19"

y,Fs,nbits,opt = load(wavname)

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

starttime = APTDecoder.starttimename(wavname)

Alon,Alat,Adata = APTDecoder.georeference(channelA,satellite_name,datatime,starttime)
figure("Channel A - geo")
APTDecoder.plot(Alon,Alat,Adata)

Blon,Blat,Bdata = BPTDecoder.georeference(channelB,satellite_name,datatime,starttime)
figure("Channel B - geo")
APTDecoder.plot(Blon,Blat,Bdata)
