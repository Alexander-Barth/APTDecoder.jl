using FileIO
import DSP
using Statistics

NOAA_SYNCA = [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
NOAA_SYNCB = [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0]

# https://web.archive.org/web/20190814072342/https://noaa-apt.mbernardi.com.ar/how-it-works.html
frequency_sync_A = 1040 # Hz

function probe(start,imageA,imageB,y_demod)
    NOAA_SYNCA = [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    NOAA_SYNCB = [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0]
    i = start

    conv = 0.

    while (i < start + imageA + imageB + length(NOAA_SYNCA) + length(NOAA_SYNCB))
        conv += y_demod[i:i+length(NOAA_SYNCA)-1]' * NOAA_SYNCA
        i += imageA
        conv += y_demod[i:i+length(NOAA_SYNCB)-1]' * NOAA_SYNCB
        i += imageB
    end
    return conv
end


am_demodulation(y2) = abs.(DSP.Util.hilbert(y2))

wavname = "/home/abarth/src/APTDecoder/test.wav"
wavname = "/mnt/data1/abarth/Backup/abarth/testapt/gqrx_20180715_150114_137100000.wav"

#wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190804_141523_137100000.wav"
wavname = "/home/abarth/testapt/gqrx_20180715_150114_137100000.wav"
wavname = "/home/abarth/gqrx_20190814_192855_137917500.wav"
wavname = "gqrx_20190804_141523_137100000.wav"

y,Fs,nbits,opt = load(wavname)

#Fs2 = 20800.
#Fs2 = 11025.
Fs2 = 11024.
Fs2 = 12480

sync_frequency = [1040., # channel A
                  832.   # channel B
                  ]

nbands = 7

sync_frame = Vector{Vector{Float64}}(undef,length(sync_frequency))
for i = 1:length(sync_frequency)
    bands_len = Fs2/sync_frequency[i]
    sync_frame[i] = -cos.(2*pi * (0:( (nbands-1) * bands_len -1 )) /  bands_len);
end
sync_frame[1] =  [-1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]

responsetype = DSP.Filters.Bandpass(400., 4400.,fs = Fs);
designmethod = DSP.Filters.Butterworth(6)

yf = DSP.filt(DSP.digitalfilter(responsetype, designmethod), y[:,1]);

#plot(y[range(1,length= 500),2])
#clf();plot(y[range(1,length= 500),2])
#plot(yf[range(1,length= 500)])

y2 = DSP.Filters.resample(yf, Float64(Fs2) / Float64(Fs) ); size(yf,1), size(y2,1)

#clf();plot(y2[range(1,length= 500)])
y_demod = am_demodulation(y2);

#clf();plot(y_demod[range(1,length= 500)])
#clf();plot(y_demod[range(100,length= 500)])
#clf();plot(y_demod[range(100,length= 5000)])
# NOAA_SYNCA = [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

syncA = vcat(repeat([0, 128, 255, 128],7),zeros(7)) .- 128
syncA = NOAA_SYNCA

function markmax(aa)
    mm = sh(aa);
    tt = zeros(size(mm))
    for i = 1:size(mm,2)
        loc = findmax(mm[:,i])[2]
        tt[loc,i] = 1
    end
    return tt[:]
end

function find_sync(y_demod,syncA)
    mindistance = 4992

    signalshifted = y_demod .- mean(y_demod);

    peaks = [(1, 0.)]
    corr_ = Float64[]
    for i in 1:(length(signalshifted)-length(syncA)-1)
        corr = syncA' * signalshifted[i : i+length(syncA)-1]
        push!(corr_,corr)

        if (i - peaks[end][1]) > mindistance
            push!(peaks,(i, corr))
        elseif corr > peaks[end][2]
            peaks[end] = (i, corr)
        end
    end

    pp = [p[1] for p in peaks];
    return pp
end
#y_demod = y_demod[4000:end]
#=
=#
inter = 5512
inter = round(Int,0.5 * Fs2)

pindex = find_sync(y_demod,sync_frame[1])

# pindex = [p[1] for p in peaks];

# pindex = 4987 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
# pindex = 1 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
# #pindex = 1 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
# pindex = 7338 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter


matrix = zeros(length(pindex),inter)


function sh(s)
    nscan = length(s) ÷ inter
    reshape(s[1:inter*nscan],(inter,nscan))
end
function splot(s)
    nscan = length(s) ÷ inter
    imshow(reverse(reverse(reshape(s[1:inter*nscan],(inter,nscan))',dims=2),dims=1),  aspect = "auto")
end


for i = 1:length(pindex)-2
   matrix[i,:] = y_demod[pindex[i] : pindex[i]+inter-1]
#   matrix[i,:] = y_demod[pindex[i] : pindex[i+1]-1]
end


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
