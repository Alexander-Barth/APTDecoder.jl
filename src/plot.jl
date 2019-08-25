function plot(plon,plat,data; cmap = "RdYlBu_r", coastlinecolor="darkgrey")
    pcolormesh(plon,plat,data,cmap=cmap)
    lon,lat,lsmask = landseamask(;resolution='l',grid=5)
    contour(lon,lat,lsmask',[0.5],linewidths=[1.],colors=coastlinecolor);
    xlim(extrema(plon))
    ylim(extrema(plat))
    return nothing
end

function makeplots(wavname,satellite_name;
                   starttime = nothing,
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
    rawname = prefix * "_raw.png"
    FileIO.save(rawname, colorview(Gray, data[:,1:3:end]./maximum(data)))

    Alon,Alat,Adata = APTDecoder.georeference(channelA,satellite_name,datatime,starttime)
    figure("Channel A - geo")
    APTDecoder.plot(Alon,Alat,Adata; coastlinecolor=coastlinecolor, cmap=cmap)
    savefig(prefix * "_channel_a.png",dpi=dpi)

    Blon,Blat,Bdata = APTDecoder.georeference(channelB,satellite_name,datatime,starttime)
    figure("Channel B - geo")
    APTDecoder.plot(Blon,Blat,Bdata; coastlinecolor=coastlinecolor, cmap=cmap)
    savefig(prefix * "_channel_b.png",dpi=dpi)
end
