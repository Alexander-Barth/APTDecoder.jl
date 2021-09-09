if Sys.islinux()
    using ImageMagick
end
import APTDecoder
using Test
using RemoteFiles
using SatelliteToolbox

@testset "decoding" begin
    wavname = "gqrx_20190825_182745_137620000.wav"

    if !isfile(wavname)
        download("https://archive.org/download/gqrx_20190825_182745_137620000/gqrx_20190825_182745_137620000.wav",wavname)
    end
    current_tles = APTDecoder.get_tle(:weather)
    tles = SatelliteToolbox.read_tle(joinpath(dirname(pathof(APTDecoder)),"..","examples","weather-20190825.txt"))

    APTDecoder.makeplots(wavname,"NOAA 15", tles = tles)

    @test isfile(replace(wavname,r"\.wav$" => "_raw.png"))

    s = randn(4,5);
    APTDecoder.reshape_signal(s[:],4) == s


    ioffset = 6
    frame_len = 1000
    sync_frame = APTDecoder.gen_sync_frame(3*4160,APTDecoder.sync_frequency)[1];
    y_demod = vcat(ones(Int,ioffset),sync_frame,ones(Int,7));
    sync_frame_index = APTDecoder.find_sync(y_demod,sync_frame,frame_len)
    @test sync_frame_index == [ioffset+1]

    tt = APTDecoder.mark_sync(y_demod,sync_frame,frame_len);
    @test tt[ioffset+1,1] ≈ 1.

    @test_throws ErrorException APTDecoder.starttimename("bogous_filename.wav")

    pngname = joinpath(dirname(@__FILE__),"gqrx_20190825_182745_137620000.png")
    datatime,channel,data = APTDecoder.wxload(pngname)
    @test length(channel) == 2

    satellite_name = "NOAA 15"
    channel = 'a'
    plon,plat,data = APTDecoder.georeference(pngname,satellite_name,channel, tles = tles)


    satellite_name = "NOAA 15"
    channel = 'x' # bogous
    @test_throws ErrorException APTDecoder.georeference(pngname,satellite_name,channel)
end

@testset "GeoMapping" begin
    @test APTDecoder.GeoMapping.azimuth(0,0,1,0) ≈ 0;
    @test APTDecoder.GeoMapping.azimuth(0,0,0,1) ≈ 90;


    @test APTDecoder.GeoMapping.distance(0,0,1,0) ≈ 1;
    @test APTDecoder.GeoMapping.distance(0,0,90,0) ≈ 90;
    @test APTDecoder.GeoMapping.distance(0,0,0,180) ≈ 180;
    @test APTDecoder.GeoMapping.distance(0,0,0,270) ≈ 90;
    @test APTDecoder.GeoMapping.distance(1,2,3,4) ≈ 2.82749366820155;

    @test APTDecoder.GeoMapping.distance(43.016666412353515625,3.3333332538604736328125,43.016666412353515625,3.3333332538604736328125) ≈ 0


    lato,lono = APTDecoder.GeoMapping.reckon(30,-80,20,40);
    @test lato ≈ 44.16661401448592
    @test lono ≈ -62.15251496909770

    lato,lono = APTDecoder.GeoMapping.reckon(-30,80,[5, 10],[40, 45]);
    @test lato ≈ [-26.12155703039504, -22.70996703614572]
    @test lono ≈ [83.57732793979254,  87.64920016442251]

    lato,lono = APTDecoder.GeoMapping.reckon([-30, 31],[80, 81],[5, 10],[40, 45]);
    @test lato ≈ [-26.12155703039504,  37.76782079033356]
    @test lono ≈ [83.57732793979254,  89.93590456974810]
end
