using PyPlot
import APTDecoder

satellite_name = "NOAA 19"
pngname = "/home/abarth/gqrx_20190804_141523_137100000.png"



#pngname = "/mnt/data1/abarth/Backup/abarth/testapt/gqrx_20180715_150114_137100000.png"

#satellite_name = "NOAA 15"
#pngname = "gqrx_20190811_075102_137620000.png";

plon,plat,data = APTDecoder.georeference(pngname,satellite_name,'a')
figure("Channel a")
APTDecoder.plot(plon,plat,data)


plon,plat,data = APTDecoder.georeference(pngname,satellite_name,'b')
figure("Channel b")
APTDecoder.plot(plon,plat,data)

