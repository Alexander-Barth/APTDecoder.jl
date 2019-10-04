function plot(plon,plat,data; cmap = "RdYlBu_r", coastlinecolor="darkgrey")
    pcolormesh(plon,plat,data,cmap=cmap)
    lon,lat,lsmask = landseamask(;resolution='l',grid=5)
    contour(lon,lat,lsmask',[0.5],linewidths=[1.],colors=coastlinecolor);
    xlim(extrema(plon))
    ylim(extrema(plat))
    return nothing
end

"""
    makeplots(wavname,satellite_name)

Decodes the APT signal in `wavname` as recorded by gqrx using
wide FM-mono demodulation.
The file name `wavname` should  have the followng structure:
`string_date_time_frequency.wav` like `gqrx_20190811_075102_137620000.wav`.
Date and time of the file name are in UTC (not local time). `satellite_name` is
the name of the satellite (generally `"NOAA 15"`, `"NOAA 18"`, `"NOAA 19"`).

# Example:

```julia
import APTDecoder

wavname = "gqrx_20190825_182745_137620000.wav"
APTDecoder.makeplots(wavname,"NOAA 15")
```

"""
function makeplots(wavname,satellite_name;
                   starttime = nothing,
                   eop = nothing,
                   prefix = replace(wavname,r".wav$" => ""),
                   qrange = (0.01,0.99),
                   coastlinecolor = "darkgray",
                   cmap = "RdYlBu_r",
                   dpi = 150)

    if starttime == nothing
        starttime = APTDecoder.starttimename(basename(wavname))
    end

    y,Fs,nbits,opt = FileIO.load(wavname)

    datatime,(channelA,channelB),data = APTDecoder.decode(y,Fs)

    vmin,vmax = quantile(view(data,:),[qrange[1],qrange[2]])
    data[data .> vmax] .= vmax;
    data[data .< vmin] .= vmin;

    # save raw image
    imagenames = (
        rawname = prefix * "_raw.png",
        channel_a = prefix * "_channel_a.png",
        channel_b = prefix * "_channel_b.png")

    FileIO.save(imagenames.rawname, colorview(Gray, data[:,1:3:end]./maximum(data)))

    Alon,Alat,Adata = APTDecoder.georeference(
        channelA,satellite_name,datatime,starttime, eop = eop)
    figure("Channel A - geo")
    APTDecoder.plot(Alon,Alat,Adata; coastlinecolor=coastlinecolor, cmap=cmap)
    savefig(imagenames.channel_a,dpi=dpi)

    Blon,Blat,Bdata = APTDecoder.georeference(
        channelB,satellite_name,datatime,starttime, eop = eop)
    figure("Channel B - geo")
    APTDecoder.plot(Blon,Blat,Bdata; coastlinecolor=coastlinecolor, cmap=cmap)
    savefig(imagenames.channel_b,dpi=dpi)

    return imagenames
end
