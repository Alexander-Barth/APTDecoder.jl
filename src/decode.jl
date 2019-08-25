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






function find_sync(y_demod,sync_frame,frame_len)
    # minimum and maximum distance between sync frames
    mindistance = (8*frame_len) ÷ 10
    maxdistance = (12*frame_len) ÷ 10

    conv_sync = DSP.conv(y_demod,reverse(sync_frame));
    # overall strongest sync frame
    index0 = findmax(conv_sync)[2];

    # look for all sync frames after the strongest sync frame
    index = index0
    after_index = Int[]
    while index + maxdistance <= length(conv_sync)
        i = findmax(conv_sync[index .+ (mindistance:maxdistance)])[2] + index+mindistance-1
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


function mark_sync(y_demod,sync_frame,frame_len)
    sync_frame_index = find_sync(y_demod,sync_frame,frame_len)
    tt = zeros(size(y_demod))
    tt[sync_frame_index] .= 1;
    return tt
end

function reshape_signal(s,frame_len)
    nscan = length(s) ÷ frame_len
    return reshape(s[1:frame_len*nscan],(frame_len,nscan))
end

"""
    datatime, (channelA,channelB), data = decode(y,Fs)

Decode the APT image in a time series `y` defined at a frequency `Fs` (in Hz).
`datatime` is the time in seconds counting from the beginning of the recording.

# Example
```julia
using FileIO
using APTDecoder

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

    # low and high frequency for the band-pass filter (in Hz)
    wpass = (400., 4400.)

    responsetype = DSP.Filters.Bandpass(wpass[1],wpass[2],fs = Fs);
    designmethod = DSP.Filters.Butterworth(6)

    #figure(4); clf(); psd(y[:,1],Fs = Fs, NFFT=1024)
    yf = DSP.filt(DSP.digitalfilter(responsetype, designmethod), y[:,1]);
    #figure(4); clf(); psd(yf[:,1],Fs = Fs, NFFT=1024)

    y2 = DSP.Filters.resample(yf, float(Fs2) / float(Fs) )

    # AM demodulation using the Hilbert Transform
    y_demod = am_demodulation(y2);

    # generate the syncronization frame at the frequency Fs2
    sync_frame = gen_sync_frame(Fs2,sync_frequency)

    # length of a frame
    frame_len = round(Int,Fs2/scans_per_seconds)

    sync_frame_index = find_sync(y_demod,sync_frame[1],frame_len)

    # complete frames
    complete_frame_index = Int[]
    for i = 1:length(sync_frame_index)
        if sync_frame_index[i]+frame_len-1 <= length(y_demod)
            push!(complete_frame_index,sync_frame_index[i])
        end
    end

    data = zeros(length(complete_frame_index),frame_len)
    datatime = (complete_frame_index .- 1) / Fs2

    for i = 1:length(complete_frame_index)
        data[i,:] = y_demod[complete_frame_index[i] : complete_frame_index[i]+frame_len-1]
    end

    # channel A and B
    channels = (view(data,:,259:2985), view(data,:,3380:6103))
    return datatime,channels,data
end


