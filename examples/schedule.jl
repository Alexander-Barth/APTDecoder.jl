using ImageMagick
using APTDecoder
using SatelliteToolbox
using Dates
using Base64
using JSON
using Twitter
import APTDecoder
using Pkg
const TOML = Pkg.TOML

tles = APTDecoder.get_tle(:weather)
config = TOML.parsefile("APTDecoder.toml")

satellites = Dict(
    "NOAA 19" => (frequency = 137_100_000,
                  protocol = :APT),
    "NOAA 18" => (frequency = 137_912_500,
                  protocol = :APT),
    "NOAA 15" => (frequency = 137_620_000,
                  protocol = :APT)
)


ground_station = (
    config["ground_station"]["latitude"],
    config["ground_station"]["longitude"],
    config["ground_station"]["altitude"])

basedir = config["basedir"]
mkpath(basedir)

eop_IAU1980 = get_iers_eop();

function get_tle(satellite_name,tles = APTDecoder.get_tle(:weather))
    return [t for t in tles if t.name == satellite_name][1]
end

function sat_time(eop_IAU1980,ground_station,tle,t0,t1)
    orbp = init_orbit_propagator(Val{:sgp4}, tle)
    ground_station_rad = (ground_station[1] * pi/180,ground_station[2] * pi/180 ,150)
    # predict for the next 3 days since epoch of the satellite
    Δt = 24*60*60*3
    out = ground_station_accesses(orbp, ground_station_rad,Δt,TEME(),ITRF(),eop_IAU1980; θ = 10*pi/180)
    # keep only time between t0 and t1
    sel = (t0 .<= out[:,1]) .& (out[:,2] .< t1)
    out = out[sel,:]
    return out
end

function twitter_upload(auth,fname)
    media = read(fname)
    r = Twitter.post_oauth("https://upload.twitter.com/1.1/media/upload.json",Dict("media" => base64encode(media)))
    resp = JSON.parse(String(r.body))
    return resp["media_id"]
end

function publish(auth,message,fnames)
    twitterauth(auth["consumer_key"], auth["consumer_token"], auth["access_token"], auth["access_secret"])
    Twitter.post_status_update(
        status = message,
        media_ids =
          join([twitter_upload(auth,fname) for fname in fnames],","))
end

# time frame of selected passes
t0 = Dates.now(Dates.UTC);
t1 = t0 + Dates.Day(1)

outdir = joinpath(basedir,Dates.format(t0,"yyyy-mm-dd"))
mkpath(outdir)

pass_satellite_name = String[]
pass_time = Matrix{DateTime}(undef,0,2)

for satellite_name in keys(satellites)
    global pass_time
    tle = get_tle(satellite_name)
    out = sat_time(eop_IAU1980,ground_station,tle,t0,t1)

    append!(pass_satellite_name,fill(satellite_name,size(out,1)))
    pass_time = vcat(pass_time,out)
end

ind = sortperm(pass_time[:,1])
pass_time = pass_time[ind,:]
pass_satellite_name = pass_satellite_name[ind]


for i = 1:size(pass_time,1)
    pass_duration = Dates.value(pass_time[i,2] - pass_time[i,1])/1000
    println("$(pass_satellite_name[i]): $(pass_time[i,1]) → $(pass_time[i,2])  $(round(pass_duration/60,digits=1)) min")
end

for i = 1:size(pass_time,1)
    sleep_time = pass_time[i,1] - Dates.now(Dates.UTC)
    # debug
    sleep_time = Dates.Second(1)

    if sleep_time > Dates.Millisecond(0)
        println("wait upto $(pass_time[i,1]) $sleep_time ")
        sleep(sleep_time)
    end

    if Dates.now(Dates.UTC) < pass_time[i,2]
        dt = Dates.now(Dates.UTC)
        println("Now $(dt) and should be $(pass_time[i,1])")
        pass_duration = pass_time[i,2] - dt
        # debug
        pass_duration = Dates.Second(10)
        frequency = satellites[pass_satellite_name[i]].frequency

        wavname = joinpath(outdir,"APTDecoder_$(Dates.format(dt,"yyyymmdd"))_$(Dates.format(dt,"HHMMSS"))_$(frequency).wav")
        println("start recording $(pass_satellite_name[i]) to file $wavname")

        # satellite is still in the sky
        record = run(pipeline(`rtl_fm -M wbfm -f 88.5e6 -E wav`, `sox -t raw -e signed -c 1 -b 16 -r 32k - $wavname`), wait = false);
        println("Recording during ",pass_duration)
        sleep(pass_duration)
        kill.(record.processes,Base.SIGINT)

        println("Finish recording\n")

        # debug
        wavname_example = "/home/abarth/src/APTDecoder/examples/gqrx_20190823_173900_137620000.wav"
        cp(wavname_example,wavname,force=true)
        pass_satellite_name[i] = "NOAA 15"

        @info("Making plots")
        imagenames = APTDecoder.makeplots(wavname,pass_satellite_name[i]; eop = eop_IAU1980)

        if i < 3
            message = "$(pass_satellite_name[i]) $(Dates.format(dt,"yyyymmdd"))_$(Dates.format(dt,"HHMMSS"))"
            publish(config["twitter"],message,[imagenames.rawname,imagenames.channel_a,imagenames.channel_b])
        end
    end
end


