function starttimename(pngname::String)
    pngname_parts = split(replace(pngname,r".png|.wav$" => ""),"_")

    if length(pngname_parts) !== 4
        error("File name $(pngname) has not the right format")
    end

    program,datastr,timestr,frequency = pngname_parts

    return DateTime(
        parse(Int,datastr[1:4]),parse(Int,datastr[5:6]),parse(Int,datastr[7:8]),
        parse(Int,timestr[1:2]),parse(Int,timestr[3:4]),parse(Int,timestr[5:6]))
end

function wxload(pngname)
    starttime = starttimename(pngname)

    data_all = convert(Array{Float32,2},imread(pngname)) :: Array{Float32,2}

    channel = (data_all[:,83:990][end:-1:1,end:-1:1],
               data_all[:,1123:2027][end:-1:1,end:-1:1])

    datatime = (0:size(data_all,1)-1)/scans_per_seconds
    return datatime,channel,data_all[end:-1:1,end:-1:1]
end

function georeference(pngname,satellite_name,channel; starttime = DateTime(1,1,1,0,0,0))
    if !(channel in ['a','b'])
        error("channel must be 'a' or 'b'")
    end

    if starttime == DateTime(1,1,1,0,0,0)
        starttime = starttimename(pngname)
    end

    data_all = convert(Array{Float32,2},imread(pngname)) :: Array{Float32,2}

    data =
        if channel == 'a'
            data_all[:,83:990];
        else
            data_all[:,1123:2027];
        end

    data = data[end:-1:1,end:-1:1]
    datatime = (0:size(data,1)-1)/scans_per_seconds

    plon,plat,data = georeference(data,satellite_name,datatime,starttime)
    return plon,plat,data
end


function get_tle(satellite_type)
    @assert satellite_type == :weather
    # get satellite orbit information (TLE)

    @RemoteFile(tle_data,
                "https://www.celestrak.com/NORAD/elements/weather.txt",
                updates=:daily)
    download(tle_data)

    tles = read_tle(path(tle_data))
end

"""
    plon,plat,data = georeference(pngname,satellite_name,channel)

Compute longitude and latitude of the NOAA APT satellite image in `pngname`
using the orbit of the satellite with the name `satellite_name`
(generally "NOAA 15", "NOAA 18", "NOAA 19").
The file name `pngname` should  have the followng structure:
`string_date_time_frequency.png` like `gqrx_20190811_075102_137620000.png`.
Date and time of the file name are in UTC.


Example:
```
satellite_name = "NOAA 15"
pngname = "gqrx_20190811_075102_137620000.png";
APTDecoder.georeference(pngname,satellite_name)
```
"""
function georeference(data,satellite_name,datatime,starttime;
                      tles = get_tle(:weather))

    tle = [t for t in tles if t.name == satellite_name][1]

    # Earth radius
    a = 6378137 # meters, a is the semi-major axis

    # swath with in meters
    # https://directory.eoportal.org/web/eoportal/satellite-missions/n/noaa-poes-series-5th-generation
    swath_m = 2900_000 # m

    Δt = 1/scans_per_seconds

    # swath with in degree (for a spherical earth)
    swath = swath_m / (a*pi/180)

    nrec = size(data,1);
    np = size(data,2);

    # compute satellite track

    orbp = init_orbit_propagator(Val{:sgp4}, tle);
    jdnow =
        if Int == Int64
            DatetoJD(starttime)
        else
            DatetoJD(Int(Dates.year(starttime)),
                     Int(Dates.month(starttime)),
                     Int(Dates.day(starttime)),
                     Int(Dates.hour(starttime)),
                     Int(Dates.minute(starttime)),
                     Int(Dates.second(starttime)))
        end

    # time [s] from the orbit epoch
    # two extra time steps (at the beginning and end)

    t = 24*60*60*(jdnow - tle.epoch) .+
        vcat([datatime[1] - Δt ],
             datatime,
             datatime[end] + Δt)

    o,r_TEME,v_TEME = propagate!(orbp, t);

    # download the Earth Orientation Parameters (EOP)
    eop_IAU1980 = get_iers_eop();

    α = range(-swath/2,stop=swath/2,length = np) # degrees

    # position of the satellite in Geodetic coordinates
    lon = zeros(length(t))
    lat = zeros(length(t))

    # Geodetic coordinates of the satellite data
    plon = zeros(length(t)-2,length(α))
    plat = zeros(length(t)-2,length(α))

    # Convert position
    # ECI(TEME) -> ECEF(ITRF) -> Geodetic coordinates
    for i = 1:length(t)
        datejd = tle.epoch + t[i]/(24*60*60)
        M = rECItoECEF(TEME(), ITRF(), datejd, eop_IAU1980)
        # position in ITRF
        r_ITRF = M * r_TEME[i]

        # position of the satellite in Geodetic coordinates
        lat[i],lon[i] = ECEFtoGeodetic(r_ITRF)
        lat[i] = 180 * lat[i]/pi
        lon[i] = 180 * lon[i]/pi
    end

    for i = 2:length(t)-1
        # direction perpenticular to the satellite ground track
        az = GeoMapping.azimuth(lat[i-1],lon[i-1],lat[i+1],lon[i+1]) - 90
        for j = 1:length(α)
            plat[i-1,j],plon[i-1,j] = GeoMapping.reckon(lat[i],lon[i],α[j],az)
        end
    end

    return plon,plat,data

end

