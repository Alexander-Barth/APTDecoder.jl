#!/bin/bash

duration="$1"
output="$2"

timeout "$duration" rtl_fm -M raw -s 140000 -f 137.9M -E dc -g 10 -p 0 /tmp/meteor_iq

#~/src/meteor_demod/src/meteor_demod -s 140000 /tmp/meteor_iq
~/src/meteor_demod/src/meteor_demod -s 140000 --batch 1  --output /tmp/foo.s /tmp/meteor_iq

#~/src/meteor_decode/src/meteor_decode LRPT_2019_10_12-21_13.s
~/src/meteor_decode/src/meteor_decode  --output "$output" /tmp/foo.s

rm -f /tmp/meteor_iq
