import APTDecoder
using Test

@testset "decoding" begin
    wavname = "gqrx_20190825_182745_137620000.wav"
    download("https://archive.org/download/gqrx_20190825_182745_137620000/gqrx_20190825_182745_137620000.wav",wavname)
    APTDecoder.makeplots(wavname,"NOAA 15")

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
end

@testset "landseamask" begin
    lon,lat,data = APTDecoder.landseamask(;resolution='c',grid=5)
    @test size(data,1) == length(lon)
    @test size(data,2) == length(lat)

    @test_throws ErrorException APTDecoder.landseamask(;resolution='c',grid=-999)
    @test_throws ErrorException APTDecoder.landseamask(;resolution='g',grid=5)
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
