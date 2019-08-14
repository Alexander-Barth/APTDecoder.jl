# install SatelliteToolbox and PyPlot

using Printf, DelimitedFiles, Dates, LinearAlgebra
using SatelliteToolbox
using PyPlot
using OceanPlot
using GeoMapping

satellite_name = "NOAA 15"
pngname = "gqrx_20190811_075102_137620000.png";

satellite_name = "NOAA 19"
pngname = "gqrx_20190804_141523_137100000.png"


program,datastr,timestr,frequency = split(replace(pngname,r".png$" => ""),"_")

start = DateTime(parse(Int,datastr[1:4]),parse(Int,datastr[5:6]),parse(Int,datastr[7:8]),
                 parse(Int,timestr[1:2]),parse(Int,timestr[3:4]),parse(Int,timestr[5:6]))


# get satellite orbit information (TLE)
fname = "weather.txt"
if !isfile(fname)
    download("https://www.celestrak.com/NORAD/elements/weather.txt",fname)
end

# Earth radius
a = 6378137 # meters, a is the semi-major axis

# swath with in meters
# https://directory.eoportal.org/web/eoportal/satellite-missions/n/noaa-poes-series-5th-generation
swath_m = 2900_000 # m

# swath with in degree (for a spherical earth)
swath = swath_m / (a*pi/180)


data_all = imread(pngname);
data = data_all[:,83:992];
data = data[end:-1:1,:]
data = data[:,end:-1:1]

nrec = size(data,1);
np = size(data,2);

tles = read_tle(fname)

tle = [t for t in tles if t.name == satellite_name][1]


orbp = init_orbit_propagator(Val{:sgp4}, tle);

jdnow = DatetoJD(start)

scans_per_seconds = 2.

# time [s] from the orbit epoch
# two extra time steps (at the beginning and end)
t = 24*60*60*(jdnow - tle.epoch) .+ (-1:nrec) / scans_per_seconds

o,r_TEME,v_TEME = propagate!(orbp, t);

#eop_IAU1980 = get_iers_eop();

α = range(-swath/2,stop=swath/2,length = np) # degree

# Convert
# ECI(TEME) -> ECEF(ITRF)

pos = zeros(length(t),3)
lon = zeros(length(t))
lat = zeros(length(t))
az = zeros(length(t)-2)

r_ITRF = zeros(length(t),3)
v_ITRF_ = zeros(length(t),3)
r_ppos = zeros(length(t),length(α),3)


plon = zeros(length(t)-2,length(α))
plat = zeros(length(t)-2,length(α))
pz = zeros(length(t)-2,length(α))


for i = 1:length(t)
    datejd = tle.epoch + t[i]/(24*60*60)
    M = rECItoECEF(TEME(), ITRF(), datejd, eop_IAU1980)
    # position and velocity in ITRF
    r_ITRF[i,:] = M * r_TEME[i]
    v_ITRF_[i,:] = M * v_TEME[i]
    v_ITRF = M * v_TEME[i]

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

r = 1

i = 1:r:size(data,1)
#i = reverse(1:r:size(data,1))
j = 1:r:size(data,2);

pcolormesh(plon[i,j],plat[i,j],data[i,j],cmap="gray")
OceanPlot.plotmap()
