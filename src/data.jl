"""
    lon,lat,data = APTDecoder.landseamask(;resolution='l',grid=5)


0 is ocean
1 is land
2 is lake

```julia
using PyPlot
lon,lat,data = APTDecoder.landseamask(;resolution='c',grid=5)
pcolormesh(lon,lat,data'); colorbar()
```
"""
function landseamask(;resolution='l',grid=5)
    if !(grid ∈ Set([1.25,2.5,5.,10.]))
        error("grid should be either 1.25, 2.5, 5 or 10")
    end
    if !(resolution ∈ Set(['c','l','i','h','f']))
        error("resolution should be either 'c','l','i','h' or 'f'")
    end

    # download remote file if it is not yet available
    @RemoteFile(lsmask, "https://raw.githubusercontent.com/matplotlib/basemap/master/lib/mpl_toolkits/basemap/data/lsmask_$(grid)min_$(resolution).bin")
    download(lsmask)

    # resolution in arc seconds
    res = round(Int,grid * 60)

    lon = (-180*3600 + res/2:res:180*3600 - res/2) / 3600
    lat = (-90*3600 + res/2:res:90*3600 - res/2) / 3600

    data = zeros(UInt8,length(lon)*length(lat));
    read!(GzipDecompressorStream(open(path(lsmask))),data);

    return lon,lat,reshape(data,length(lon),length(lat))
end
