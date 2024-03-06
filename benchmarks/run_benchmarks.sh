#!/bin/sh
hyperfine --show-output -L radius 1,4,10 -L output 1,2 -N 'vspipe --arg radius={radius} --start 0 --end 700 --outputindex {output} test_temporal_median.vpy --'
hyperfine --show-output -L radius 1,7 -L output 1,2 -N 'vspipe --arg radius={radius} --start 0 --end 700 --outputindex {output} test_temporal_soften.vpy --'
