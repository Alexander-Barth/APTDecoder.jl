using FileIO
import DSP
using Statistics

NOAA_SYNCA = [0, 0, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
NOAA_SYNCB = [0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 1, 1, 0, 0, 0]


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

y,Fs,nbits,opt = load(wavname)

#Fs2 = 20800.
Fs2 = 11025.
Fs2 = 11024.
Fs2 = 11024.
#Fs2 = 20800.
#Fs2 = 20800.
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

mindistance = 2000
mindistance = 5000

y_demod = y_demod[4000:end]

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

len_line = 2080
len_line = round(Int,0.5 * Fs2)
len_line = 5512
len_line = 5522
inter = 5512
inter = round(Int,0.5 * Fs2)

pp = [p[1] for p in peaks];

pp = 4987 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
pp = 1 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
#pp = 1 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter
pp = 7338 .+ (0 : length(y_demod) ÷ inter - 2 ) * inter

matrix = zeros(length(pp),inter)

for i = 1:length(pp)-1
#   matrix[i,:] = signalshifted[pp[i] - length(syncA) : pp[i] + len_line - 1]
#   matrix[i,:] = signalshifted[pp[i] : pp[i] + len_line - 1]
   matrix[i,:] = signalshifted[pp[i] : pp[i+1]-1]
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
