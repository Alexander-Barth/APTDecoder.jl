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
    aa = DSP.conv(y_demod,reverse(sync_frame));
    index0 = findmax(aa)[2];
    index = index0
    after_index = []
    while index + maxdistance <= length(aa)
        i = findmax(aa[index .+ (mindistance:maxdistance)])[2] + index+mindistance-1
        push!(after_index,i)
        index = i
    end

    index = index0
    before_index = []
    while index - maxdistance >= 1
        i = findmax(aa[index-maxdistance : index-mindistance])[2] + index-maxdistance-1
        push!(before_index,i)
        index = i
    end

    pindex = vcat(reverse(before_index),[index0],after_index)
    return pindex .- (length(sync_frame) - 1)
end


function mark_sync(y_demod,syncA,inter)
    pindex = find_sync(y_demod,syncA,inter)
    tt = zeros(size(y_demod))
    tt[pindex] .= 1;
    return tt
end

wavname = "/home/abarth/src/APTDecoder/test.wav"
wavname = "/mnt/data1/abarth/Backup/abarth/testapt/gqrx_20180715_150114_137100000.wav"

#wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190804_141523_137100000.wav"
wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190814_192855_137917500.wav"
wavname = "gqrx_20190804_141523_137100000.wav"

y,Fs,nbits,opt = load(wavname)

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

responsetype = DSP.Filters.Bandpass(400., 4400.,fs = Fs);
designmethod = DSP.Filters.Butterworth(6)

yf = DSP.filt(DSP.digitalfilter(responsetype, designmethod), y[:,1]);

y2 = DSP.Filters.resample(yf, float(Fs2) / float(Fs) )

y_demod = am_demodulation(y2);


sync_frame = gen_sync_frame(Fs2)

inter = round(Int,Fs2/scans_per_seconds)

pindex = find_sync(y_demod,sync_frame[1],inter)

matrix = zeros(length(pindex),inter)


function sh(s)
    nscan = length(s) ÷ inter
    reshape(s[1:inter*nscan],(inter,nscan))
end
function splot(s)
    nscan = length(s) ÷ inter
    imshow(reverse(reverse(reshape(s[1:inter*nscan],(inter,nscan))',dims=2),dims=1),  aspect = "auto")
end


for i = 1:length(pindex)
    if pindex[i]+inter-1 <= length(y_demod)
        matrix[i,:] = y_demod[pindex[i] : pindex[i]+inter-1]
        #   matrix[i,:] = y_demod[pindex[i] : pindex[i+1]-1]
    end
end

#tt_ = zeros(size(y_demod));tt_[pindex_] .= 1;
#tt = zeros(size(y_demod));tt[pindex] .= 1;

#=
figure();plot(y_demod,ls="-",marker=".",lw=0.5,ms=1)
peaks
size(matrix)
=#

#nl = length(peaks) ÷ 2
#mm = reshape(matrix[1:nl*2,:],nl,2,size(matrix,2));
#=
clf();pcolormesh(mm[:,1,:]')
=#

vmin,vmax = quantile(view(matrix,:),[0.01,0.99])
matrix[matrix .> vmax] .= vmax;
matrix[matrix .< vmin] .= vmin;

#figure(7); clf(); imshow(matrix[end:-1:1,end:-1:1], aspect="auto"); colorbar();
