#!/bin/sh

# Temporal Median benchmarks
hyperfine --show-output --shell=none \
    --runs 3 --sort command --export-csv bench_temporal_median.csv --export-markdown bench_temporal_median.md \
    --parameter-list output 2,1,3 --parameter-list radius 1,4,10 --parameter-list format u8,u16,f16,f32 \
    'vspipe --arg radius={radius} --arg format={format} --outputindex {output} test_temporal_median.vpy --'

# Quick testing of zsmooth TemporalMedian for all formats.
# hyperfine --show-output --shell=none \
#     --runs 3 --sort command \
#     --parameter-list output zsmooth --parameter-list radius 1,4 --parameter-list format u8,u16,f16,f32 \
#     'vspipe --arg radius={radius} --arg format={format} --arg output={output} test_temporal_median.vpy --'

# Temporal Soften benchmarks
hyperfine --show-output --shell=none \
    --runs 3 --sort command --export-csv bench_temporal_soften.csv --export-markdown bench_temporal_soften.md \
    --parameter-list output 2,1 --parameter-list radius 1,7 --parameter-list format u8,u16,f16,f32 \
    'vspipe --arg radius={radius} --arg format={format} --outputindex {output} test_temporal_soften.vpy --'
