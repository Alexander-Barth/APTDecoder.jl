

using ImageMagick
using APTDecoder
using SatelliteToolbox
using Dates
using Base64
using JSON
using Twitter
import APTDecoder
using PyPlot
using PyCall
using TimeZones

plt.ioff()
#using Pkg
#const TOML = Pkg.TOML

#config = TOML.parsefile("APTDecoder.toml")
config = JSON.parsefile("APTDecoder.json")

tles = APTDecoder.get_tle(:weather)

eop_IAU1980 = get_iers_eop();


const satellites = Dict(
    "NOAA 19" => (frequency = 137_100_000,
                  protocol = :APT),
    "NOAA 18" => (frequency = 137_912_500,
                  protocol = :APT),
    "NOAA 15" => (frequency = 137_620_000,
                  protocol = :APT)
)


lt(dt::DateTime) = astimezone(ZonedDateTime(dt,tz"UTC"),localzone())

function get_tle(satellite_name,tles = APTDecoder.get_tle(:weather))
    return [t for t in tles if t.name == satellite_name][1]
end

function sat_time(eop_IAU1980,ground_station,tle,t0,t1)
    orbp = init_orbit_propagator(Val{:sgp4}, tle)
    ground_station_rad = (ground_station[2] * pi/180,ground_station[1] * pi/180 ,ground_station[3])
    # predict for the next 3 days since epoch of the satellite
    Δt = 24*60*60*3
    out = ground_station_accesses(orbp, ground_station_rad,Δt,TEME(),ITRF(),eop_IAU1980; θ = 30*pi/180)
    # keep only time between t0 and t1
    sel = (t0 .<= out[:,1]) .& (out[:,2] .< t1)
    @show tle.name, out
    out = out[sel,:]
    return out
end

function twitter_upload(auth,fname)
    media = read(fname)
    r = Twitter.post_oauth("https://upload.twitter.com/1.1/media/upload.json",Dict("media" => base64encode(media)))
    resp = JSON.parse(String(r.body))
    return resp["media_id_string"]
end

function publish(auth,message,fnames)
    twitterauth(auth["consumer_key"], auth["consumer_token"], auth["access_token"], auth["access_secret"])
    Twitter.post_status_update(
        status = message,
        media_ids =
        join([twitter_upload(auth,fname) for fname in fnames],","))
end

function process(config,tles,eop_IAU1980,t0; debug = false, tz_offset = Dates.Hour(2))
    pygc = PyCall.pyimport("gc")

    ground_station = (
        config["ground_station"]["latitude"],
        config["ground_station"]["longitude"],
        config["ground_station"]["altitude"])

    basedir = config["basedir"]
    mkpath(basedir)

    t1 = t0 + Dates.Day(1)

    outdir = joinpath(basedir,Dates.format(t0,"yyyy-mm-dd"))
    mkpath(outdir)

    pass_satellite_name = String[]
    pass_time = Matrix{DateTime}(undef,0,2)

    for satellite_name in keys(satellites)
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
        println("$(pass_satellite_name[i]): $(lt(pass_time[i,1])) → $(lt(pass_time[i,2]))  $(round(pass_duration/60,digits=1)) min")
    end

    for i = 1:size(pass_time,1)
        sleep_time = pass_time[i,1] - Dates.now(Dates.UTC)
        # debug
	    if debug
            sleep_time = Dates.Second(1)
	    end

        if sleep_time > Dates.Millisecond(0)
            println("wait upto $(lt(pass_time[i,1])) for $(pass_satellite_name[i]) $sleep_time ")
            sleep(sleep_time)
        end

        if Dates.now(Dates.UTC) < pass_time[i,2]
            dt = Dates.now(Dates.UTC)
            println("Now $(lt(dt)) and should be $(lt(pass_time[i,1]))")
            pass_duration = pass_time[i,2] - dt
            # debug
	        if debug
	            pass_duration = Dates.Second(10)
	        end
            frequency = satellites[pass_satellite_name[i]].frequency

            wavname = joinpath(outdir,"APTDecoder_$(Dates.format(dt,"yyyymmdd"))_$(Dates.format(dt,"HHMMSS"))_$(frequency).wav")
            @info("start recording $(pass_satellite_name[i]) to file $wavname")

            # satellite is still in the sky
            #record = run(pipeline(`rtl_fm -f $(frequency) -s 60k -g 45 -p 55 -E wav -E deemp -F 9 -`,`sox -t raw -r 60000 -e signed -b 32 - $(wavname)`), wait = false);

	        # https://web.archive.org/web/20191007192042/http://ajoo.blog/intro-to-rtl-sdr-part-ii-software.html
	        gain = 10
	        sampling_rate = 60_000
	        sampling_rate = 48_000
	        ppm_error = 55
	        ppm_error = 0
	        fir_size = 9
	        #fir_size = 0

            #to check
            #arctan_method = "fast"
            # -E offset
            # -A $(arctan_method)
	        #record = run(pipeline(`rtl_fm -f $(frequency) -s 60k -g 45 -p 55 -E wav -E deemp -F 9 - `,`sox -t wav - $wavname rate 11025`), wait = false);
	        record = run(pipeline(`rtl_fm -f $(frequency) -s $(sampling_rate) -g $(gain) -p $(ppm_error) -E wav -E deemp -F $(fir_size) - `,`sox -t wav - $wavname rate 11025`), wait = false);
	        # get FM radio for debugging
            #record = run(pipeline(`rtl_fm -M wbfm -f 88.5e6 -E wav`, `sox -t raw -e signed -c 1 -b 16 -r 32k - $wavname`), wait = false);
            println("Recording during ",pass_duration)
            sleep(pass_duration)
            kill.(record.processes,Base.SIGINT)

            println("Finish recording\n")
	        sleep(10)
            # debug
	        if debug
                wavname_example = joinpath(dirname(pathof(APTDecoder)),"..","examples","gqrx_20190823_173900_137620000.wav")
                cp(wavname_example,wavname,force=true)
                pass_satellite_name[i] = "NOAA 15"
	        end

            println("Making plots")
	        @show wavname,pass_satellite_name[i]
            imagenames = APTDecoder.makeplots(wavname,pass_satellite_name[i]; eop = eop_IAU1980)
            close("all")

            #if i < 3
            message = "$(pass_satellite_name[i]) $(lt(dt))"
            if i < length(pass_satellite_name)
                message *= " - next at $(lt(pass_time[i+1,1]))"
            end

            publish(config["twitter"],message,[imagenames.rawname,imagenames.channel_a,imagenames.channel_b])
            #end
        end

        pygc.collect()
    end

end

#if isdir("/tmp/APTDecoder")
#    run(`rm -R /tmp/APTDecoder/`)
#end
# time frame of selected passes
t0 = Dates.now(Dates.UTC);
process(config,tles,eop_IAU1980,t0)
