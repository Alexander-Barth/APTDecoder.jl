using FileIO
import DSP
using Statistics

am_demodulation(y2) = abs.(DSP.Util.hilbert(y2))

function gen_sync_frame(Fs2,sync_frequency)
    nbands = 7
    sync_frame = Vector{Vector{Int}}(undef,length(sync_frequency))

    i = 1;
    pulse_len = round(Int,Fs2/(2*sync_frequency[i]))
    # 7 pulses followed by silence
    sync_frame[i] = vcat(
        fill(-1,pulse_len),
        repeat(vcat(fill(-1,pulse_len),
                    fill(1,pulse_len)),
               nbands),
        fill(-1,5*pulse_len ))

    i = 2;
    pulse_len_on  = round(Int,3/5 * Fs2/(sync_frequency[i]))
    pulse_len_off = round(Int,2/5 * Fs2/(sync_frequency[i]))
    # 7 pulses followed by silence
    sync_frame[i] = vcat(
        fill(-1,pulse_len_off ),
        repeat(vcat(fill(-1,pulse_len_off),
                    fill(1,pulse_len_on)),
               nbands),
        fill(-1,pulse_len_on )) # the last -1 is as long a the previous +1

    return sync_frame
end






function find_sync(y_demod,sync_frame,inter)
    # minimum and maximum distance between sync frames
    mindistance = (8*inter) ÷ 10
    maxdistance = (12*inter) ÷ 10

    conv_sync = DSP.conv(y_demod,reverse(sync_frame));
    # overall strongest sync frame
    index0 = findmax(conv_sync)[2];

    # look for all sync frames after the strongest sync frame
    index = index0
    after_index = Int[]
    while index + maxdistance <= length(conv_sync)
        i = findmax(conv_sync[index .+ (mindistance:maxdistance)])[2] + index+mindistance-1

        if i+inter > length(conv_sync)
            # ignore incomplete scan lines
            break
        end

        push!(after_index,i)
        index = i
    end

    # look for all sync frames before the strongest sync frame
    index = index0
    before_index = Int[]
    while index - maxdistance >= 1
        i = findmax(conv_sync[index-maxdistance : index-mindistance])[2] + index-maxdistance-1
        push!(before_index,i)
        index = i
    end

    sync_frame_index = vcat(reverse(before_index),[index0],after_index)
    return sync_frame_index .- (length(sync_frame) - 1)
end


function mark_sync(y_demod,sync_frame,inter)
    sync_frame_index = find_sync(y_demod,sync_frame,inter)
    tt = zeros(size(y_demod))
    tt[sync_frame_index] .= 1;
    return tt
end

function reshape_signal(s,inter)
    nscan = length(s) ÷ inter
    return reshape(s[1:inter*nscan],(inter,nscan))
end

"""
    datatime, (channelA,channelB), data = decode(y,Fs)

Decode the APT image in a time series `y` defined at a frequency `Fs` (in Hz).
`datatime` is the time in seconds counting from the beginning of the recording.

# Example
```julia

wavname = "gqrx_20190804_141523_137100000.wav"
y,Fs,nbits,opt = load(wavname)
datatime,(channelA,channelB),data = APTDecode.decode(y,Fs)

```
"""
function decode(y,Fs)
    # Fs2 should be a multiple of 4160 Hz and least 8320 Hz
    # 4160 is the least common multiple of 1040 and 832 (the frequency of the
    # sync A and B pulses)

    Fs2 = 3*4160

    # https://web.archive.org/web/20190814072342/https://noaa-apt.mbernardi.com.ar/how-it-works.html
    # frequency ratio is 5/4
    sync_frequency = [1040., # channel A
                      832.   # channel B
                      ]

    scans_per_seconds = 2

    # low and high frequency for the band-pass filter (in Hz)
    wpass = (400., 4400.)

    responsetype = DSP.Filters.Bandpass(wpass[1],wpass[2],fs = Fs);
    designmethod = DSP.Filters.Butterworth(6)

    yf = DSP.filt(DSP.digitalfilter(responsetype, designmethod), y[:,1]);

    y2 = DSP.Filters.resample(yf, float(Fs2) / float(Fs) )

    y_demod = am_demodulation(y2);

    sync_frame = gen_sync_frame(Fs2,sync_frequency)

    inter = round(Int,Fs2/scans_per_seconds)

    sync_frame_index = find_sync(y_demod,sync_frame[1],inter)

    data = zeros(length(sync_frame_index),inter)
    datatime = (sync_frame_index .- 1) / Fs2

    for i = 1:length(sync_frame_index)
        data[i,:] = y_demod[sync_frame_index[i] : sync_frame_index[i]+inter-1]
    end

    # channel A and B
    channels = (view(data,:,259:2985), view(data,:,3380:6103))
    #channels = (view(data,:,259:3185), view(data,:,3380:6103))
    return datatime,channels,data
end


function makeplots(wavname,satellite_name; starttime = nothing, prefix = nothing,
                   qrange = (0.01,0.99))
    if starttime == nothing
        starttime = APTDecoder.starttimename(basename(wavname))
    end

    if prefix == nothing
        prefix = replace(wavname,r".wav$" => "")
    end

    @show starttime

    y,Fs,nbits,opt = load(wavname)

    datatime,(channelA,channelB),data = APTDecoder.decode(y,Fs)

    vmin,vmax = quantile(view(data,:),[qrange[1],qrange[1]])
    data[data .> vmax] .= vmax;
    data[data .< vmin] .= vmin;


    dpi = 150

    Alon,Alat,Adata = APTDecoder.georeference(channelA,satellite_name,datatime,starttime)
    figure("Channel A - geo")
    APTDecoder.plot(Alon,Alat,Adata)
    savefig(prefix * "_channel_a.png",dpi=dpi)

    Blon,Blat,Bdata = APTDecoder.georeference(channelB,satellite_name,datatime,starttime)
    figure("Channel B - geo")
    APTDecoder.plot(Blon,Blat,Bdata)
    savefig(prefix * "_channel_b.png",dpi=dpi)
end
