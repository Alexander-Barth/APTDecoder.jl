

"""
    plon,plat,data = georeference(pngname,satellite_name,channel)

Compute longitude and latitude of the NOAA APT satellite image in `pngname`
using the orbit of the provided satellite with the name `satellite_name`
(generally "NOAA 15", "NOAA 18", "NOAA 19").
The file name `pngname` should  have the followng structure:
`string_date_time_frequency.png` like `gqrx_20190811_075102_137620000.png`
Date and time of the file name are in UTC. This is the the default file name
output of gqrx.

Example:
```
satellite_name = "NOAA 15"
pngname = "gqrx_20190811_075102_137620000.png";
georeference(pngname,satellite_name)
```
"""
function georeference(pngname,satellite_name,channel)

                      starttime = DateTime(1,1,1,0,0,0)
    if !(channel in ['a','b'])
        error("channel must be 'a' or 'b'")
    end

    if starttime == DateTime(1,1,1,0,0,0)
        pngname_parts = split(replace(pngname,r".png$" => ""),"_")

        if length(pngname_parts) !== 4
            error("File name $(pngname) has not the right format")
        end

        program,datastr,timestr,frequency = pngname_parts

        starttime = DateTime(parse(Int,datastr[1:4]),parse(Int,datastr[5:6]),parse(Int,datastr[7:8]),
                             parse(Int,timestr[1:2]),parse(Int,timestr[3:4]),parse(Int,timestr[5:6]))
    end

    # get satellite orbit information (TLE)
    fname = "weather.txt"
    if !isfile(fname)
        download("https://www.celestrak.com/NORAD/elements/weather.txt",fname)
    end
    tles = read_tle(fname)
    tle = [t for t in tles if t.name == satellite_name][1]

    # Earth radius
    a = 6378137 # meters, a is the semi-major axis

    # swath with in meters
    # https://directory.eoportal.org/web/eoportal/satellite-missions/n/noaa-poes-series-5th-generation
    swath_m = 2900_000 # m

    # swath with in degree (for a spherical earth)
    swath = swath_m / (a*pi/180)

    data_all = convert(Array{Float32,2},imread(pngname)) :: Array{Float32,2}

    data =
        if channel == 'a'
            data_all[:,83:990];
        else
            data_all[:,1123:2027];
        end

    data = data[end:-1:1,:]
    data = data[:,end:-1:1]

    nrec = size(data,1);
    np = size(data,2);

    # compute satellite track

    orbp = init_orbit_propagator(Val{:sgp4}, tle);

    jdnow = DatetoJD(starttime)

    scans_per_seconds = 2.

    # time [s] from the orbit epoch
    # two extra time steps (at the beginning and end)
    t = 24*60*60*(jdnow - tle.epoch) .+ (-1:nrec) / scans_per_seconds

    o,r_TEME,v_TEME = propagate!(orbp, t);

    # Convert position
    # ECI(TEME) -> ECEF(ITRF)

    eop_IAU1980 = get_iers_eop();

    α = range(-swath/2,stop=swath/2,length = np) # degree

    pos = zeros(length(t),3)
    lon = zeros(length(t))
    lat = zeros(length(t))
    az = zeros(length(t)-2)

    r_ITRF = zeros(length(t),3)
    ground_station_TEME = zeros(length(t),3)
    v_ITRF_ = zeros(length(t),3)
    r_ppos = zeros(length(t),length(α),3)

    plon = zeros(length(t)-2,length(α))
    plat = zeros(length(t)-2,length(α))
    pz = zeros(length(t)-2,length(α))

    # ground station
    glat = 50.5640 * pi/180
    glon = 5.5759 * pi/180
    gz = 200

    ground_station_ITRF = GeodetictoECEF(glat,glon,gz)

    for i = 1:length(t)
        datejd = tle.epoch + t[i]/(24*60*60)
        M = rECItoECEF(TEME(), ITRF(), datejd, eop_IAU1980)
        # position and velocity in ITRF
        r_ITRF[i,:] = M * r_TEME[i]
        v_ITRF_[i,:] = M * v_TEME[i]
        v_ITRF = M * v_TEME[i]

        ground_station_TEME[i,:] = M \ ground_station_ITRF

        pos[i,:] = collect(ECEFtoGeodetic(r_ITRF[i,:]))
        lat[i] = 180 * pos[i,1]/pi
        lon[i] = 180 * pos[i,2]/pi
    end

    for i = 2:length(t)-1
        az[i-1] = GeoMapping.azimuth(lat[i-1],lon[i-1],lat[i+1],lon[i+1]) - 90
        for j = 1:length(α)
            plat[i-1,j],plon[i-1,j] = GeoMapping.reckon(lat[i],lon[i],α[j],az[i-1])
        end
    end

    #=
    # Doppler-shift
    c = 3e8
    d = ground_station_TEME - reduce(hcat,r_TEME)'
    vel = (d[3:end,:] - d[1:end-2,:]) * scans_per_seconds/2;

    d2 = d[2:end-1,:];
    e_obs = d2 ./ sqrt.(sum(abs2,d2,dims=2));
    vv = sum(vel .* e_obs,dims = 2)[:,1]

    ff = sqrt.((c .+ vv)./(c .- vv));
    =#

    return plon,plat,data

end

function plot(plon,plat,data)
    pcolormesh(plon,plat,data,cmap="gray")
    OceanPlot.plotmap(patchcolor = nothing, coastlinecolor = "r")
end
