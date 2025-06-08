# Benchmarks
All benchmarks are run single-threaded (`core.num_threads = 1`) with a max cache size of 1GB (`core.max_cache_size = 1024`) 
to provided the greatest stability of FPS numbers between runs. 

So while the benchmarks show fast results, you'll see even faster by using Zsmooth when using a fully threaded VapourSynth script.

## Table of Contents
* [0.10 - Zig 0.14.1 - ARM NEON](#010---zig-0141---arm-neon-aarch64-macos)
* [0.10 - Zig 0.14.1 - AVX2](#010---zig-0141---avx2)
* [0.9 - Zig 0.14.0 - ARM NEON](#09---zig-0140---arm-neon-aarch64-macos)
* [0.9 - Zig 0.14.0 - AVX512](#09---zig-0140---avx512-znver4)
* [0.9 - Zig 0.14.0 - AVX2](#09---zig-0140---avx2)
* [0.9 - Zig 0.12.1 - AVX2](#09---zig-0121---avx2)

## 0.10 - Zig 0.14.1 - ARM NEON (aarch64-macos)
Source: BlankClip YUV420, 1920x1080

Machine: M4 Mac Mini, 16GB

OS: Darwin Mac.lan 24.5.0 Darwin Kernel Version 24.5.0: Tue Apr 22 19:54:43 PDT 2025; root:xnu-11417.121.6~2/RELEASE_ARM64_T8132 arm64  

CPU tuning: aarch64-macos

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6422.07 | 6471.74 | 6426.53 | 6440.113 | 22.437 |
| Clense | rg | u8 | function=Clense | 6422.28 | 6476.5 | 6423.02 | 6440.600 | 25.387 |
| Clense | zsmooth | u8 | function=ForwardClense | 6118.57 | 6199.19 | 6121.11 | 6146.290 | 37.420 |
| Clense | rg | u8 | function=ForwardClense | 1154.7 | 1198.17 | 1182.55 | 1178.473 | 17.979 |
| Clense | zsmooth | u8 | function=BackwardClense | 5903.2 | 6390.6 | 6181.66 | 6158.487 | 199.654 |
| Clense | rg | u8 | function=BackwardClense | 1168.11 | 1203.41 | 1198.13 | 1189.883 | 15.546 |
| Clense | zsmooth | u16 | function=Clense | 836.34 | 850.29 | 848.29 | 844.973 | 6.159 |
| Clense | rg | u16 | function=Clense | 784.58 | 850.41 | 848.93 | 827.973 | 30.690 |
| Clense | zsmooth | u16 | function=ForwardClense | 820.54 | 830.73 | 830.62 | 827.297 | 4.778 |
| Clense | rg | u16 | function=ForwardClense | 609.43 | 628.49 | 618.23 | 618.717 | 7.789 |
| Clense | zsmooth | u16 | function=BackwardClense | 848.57 | 853.31 | 848.66 | 850.180 | 2.214 |
| Clense | rg | u16 | function=BackwardClense | 624.5 | 631.22 | 627.36 | 627.693 | 2.754 |
| Clense | zsmooth | f32 | function=Clense | 710.72 | 722.95 | 717.46 | 717.043 | 5.002 |
| Clense | rg | f32 | function=Clense | 700.55 | 730.68 | 719.34 | 716.857 | 12.425 |
| Clense | zsmooth | f32 | function=ForwardClense | 715.14 | 732.01 | 718.4 | 721.850 | 7.306 |
| Clense | rg | f32 | function=ForwardClense | 348.84 | 376.2 | 375.06 | 366.700 | 12.637 |
| Clense | zsmooth | f32 | function=BackwardClense | 545.67 | 740.09 | 708.17 | 664.643 | 85.130 |
| Clense | rg | f32 | function=BackwardClense | 373.59 | 374.79 | 374.62 | 374.333 | 0.530 |
| DegrainMedian | zsmooth | u8 | mode=0 | 768.86 | 771.36 | 769.87 | 770.030 | 1.027 |
| DegrainMedian | dgm | u8 | mode=0 | 147.15 | 148.06 | 147.84 | 147.683 | 0.388 |
| DegrainMedian | zsmooth | u8 | mode=1 | 212.06 | 212.75 | 212.25 | 212.353 | 0.291 |
| DegrainMedian | dgm | u8 | mode=1 | 79.07 | 79.29 | 79.26 | 79.207 | 0.097 |
| DegrainMedian | zsmooth | u8 | mode=2 | 212.97 | 213.41 | 213.31 | 213.230 | 0.188 |
| DegrainMedian | dgm | u8 | mode=2 | 79.33 | 79.43 | 79.33 | 79.363 | 0.047 |
| DegrainMedian | zsmooth | u8 | mode=3 | 228.63 | 228.75 | 228.68 | 228.687 | 0.049 |
| DegrainMedian | dgm | u8 | mode=3 | 83.34 | 83.37 | 83.35 | 83.353 | 0.012 |
| DegrainMedian | zsmooth | u8 | mode=4 | 212.57 | 212.73 | 212.67 | 212.657 | 0.066 |
| DegrainMedian | dgm | u8 | mode=4 | 79.2 | 79.94 | 79.29 | 79.477 | 0.330 |
| DegrainMedian | zsmooth | u8 | mode=5 | 209.57 | 211.13 | 210.33 | 210.343 | 0.637 |
| DegrainMedian | dgm | u8 | mode=5 | 109.99 | 110.87 | 110.52 | 110.460 | 0.362 |
| DegrainMedian | zsmooth | u16 | mode=0 | 241.88 | 242.03 | 241.94 | 241.950 | 0.062 |
| DegrainMedian | dgm | u16 | mode=0 | 138.33 | 138.38 | 138.33 | 138.347 | 0.024 |
| DegrainMedian | zsmooth | u16 | mode=1 | 97.56 | 98.26 | 98.03 | 97.950 | 0.291 |
| DegrainMedian | dgm | u16 | mode=1 | 80.39 | 81 | 80.85 | 80.747 | 0.260 |
| DegrainMedian | zsmooth | u16 | mode=2 | 98.2 | 98.27 | 98.21 | 98.227 | 0.031 |
| DegrainMedian | dgm | u16 | mode=2 | 81.02 | 81.21 | 81.02 | 81.083 | 0.090 |
| DegrainMedian | zsmooth | u16 | mode=3 | 104.46 | 104.74 | 104.53 | 104.577 | 0.119 |
| DegrainMedian | dgm | u16 | mode=3 | 85.56 | 85.77 | 85.59 | 85.640 | 0.093 |
| DegrainMedian | zsmooth | u16 | mode=4 | 98.06 | 98.17 | 98.06 | 98.097 | 0.052 |
| DegrainMedian | dgm | u16 | mode=4 | 80.99 | 81.25 | 81.19 | 81.143 | 0.111 |
| DegrainMedian | zsmooth | u16 | mode=5 | 94.83 | 94.86 | 94.83 | 94.840 | 0.014 |
| DegrainMedian | dgm | u16 | mode=5 | 100.25 | 100.27 | 100.26 | 100.260 | 0.008 |
| DegrainMedian | zsmooth | f32 | mode=0 | 129.55 | 130.32 | 130.26 | 130.043 | 0.350 |
| DegrainMedian | zsmooth | f32 | mode=1 | 72.05 | 72.19 | 72.14 | 72.127 | 0.058 |
| DegrainMedian | zsmooth | f32 | mode=2 | 79.24 | 79.41 | 79.4 | 79.350 | 0.078 |
| DegrainMedian | zsmooth | f32 | mode=3 | 83.05 | 83.41 | 83.32 | 83.260 | 0.153 |
| DegrainMedian | zsmooth | f32 | mode=4 | 78.75 | 78.82 | 78.75 | 78.773 | 0.033 |
| DegrainMedian | zsmooth | f32 | mode=5 | 98.33 | 98.95 | 98.41 | 98.563 | 0.275 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1485.57 | 1488.46 | 1486.33 | 1486.787 | 1.223 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 580.95 | 582.86 | 581.3 | 581.703 | 0.830 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 665.14 | 666.3 | 665.3 | 665.580 | 0.513 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 300.21 | 301.64 | 301.37 | 301.073 | 0.620 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 571.42 | 573.98 | 571.49 | 572.297 | 1.191 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 376.36 | 377.29 | 377.17 | 376.940 | 0.413 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 319.95 | 322.36 | 321.49 | 321.267 | 0.996 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 229.84 | 230.06 | 230.01 | 229.970 | 0.094 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 337.8 | 340.43 | 338.21 | 338.813 | 1.155 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 104.86 | 105.01 | 104.88 | 104.917 | 0.066 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 376.14 | 402.84 | 377.38 | 385.453 | 12.305 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 180.93 | 192.31 | 187.41 | 186.883 | 4.661 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 49.94 | 50.02 | 50.02 | 49.993 | 0.038 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 282.54 | 297.85 | 294.97 | 291.787 | 6.643 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 115.2 | 116.94 | 116.91 | 116.350 | 0.813 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 28.5 | 28.54 | 28.53 | 28.523 | 0.017 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 144.89 | 149.01 | 148.94 | 147.613 | 1.926 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 35.31 | 35.34 | 35.34 | 35.330 | 0.014 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 11.03 | 11.04 | 11.03 | 11.033 | 0.005 |
| Median | zsmooth | u8 | radius=1 | 1820.71 | 1985.38 | 1919.4 | 1908.497 | 67.667 |
| Median | std | u8 | radius=1 | 56.34 | 56.36 | 56.35 | 56.350 | 0.008 |
| Median | ctmf | u8 | radius=1 | 18.43 | 18.43 | 18.43 | 18.430 | 0.000 |
| Median | zsmooth | u8 | radius=2 | 451.09 | 452.27 | 451.3 | 451.553 | 0.514 |
| Median | ctmf | u8 | radius=2 | 457.84 | 461.27 | 460.72 | 459.943 | 1.504 |
| Median | zsmooth | u8 | radius=3 | 78.33 | 78.53 | 78.48 | 78.447 | 0.085 |
| Median | ctmf | u8 | radius=3 | 18.32 | 18.33 | 18.33 | 18.327 | 0.005 |
| Median | zsmooth | u16 | radius=1 | 509.18 | 511.78 | 510.08 | 510.347 | 1.078 |
| Median | std | u16 | radius=1 | 53.08 | 53.16 | 53.15 | 53.130 | 0.036 |
| Median | ctmf | u16 | radius=1 | 0.37 | 0.37 | 0.37 | 0.370 | 0.000 |
| Median | zsmooth | u16 | radius=2 | 193.81 | 194.01 | 193.88 | 193.900 | 0.083 |
| Median | ctmf | u16 | radius=2 | 188.14 | 189 | 188.85 | 188.663 | 0.375 |
| Median | zsmooth | u16 | radius=3 | 40.67 | 40.79 | 40.76 | 40.740 | 0.051 |
| Median | ctmf | u16 | radius=3 | 0.08 | 0.08 | 0.08 | 0.080 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 247.37 | 250.91 | 247.46 | 248.580 | 1.648 |
| Median | std | f32 | radius=1 | 80.06 | 80.93 | 80.49 | 80.493 | 0.355 |
| Median | zsmooth | f32 | radius=2 | 50.98 | 51.16 | 51.1 | 51.080 | 0.075 |
| Median | ctmf | f32 | radius=2 | 51.82 | 52.03 | 51.92 | 51.923 | 0.086 |
| Median | zsmooth | f32 | radius=3 | 17.41 | 17.45 | 17.44 | 17.433 | 0.017 |
| RemoveGrain | zsmooth | u8 | mode=1 | 2372.65 | 2611.7 | 2457.68 | 2480.677 | 98.937 |
| RemoveGrain | rg | u8 | mode=1 | 721.85 | 730.78 | 728.9 | 727.177 | 3.844 |
| RemoveGrain | zsmooth | u8 | mode=4 | 1767.81 | 1841.26 | 1809.76 | 1806.277 | 30.087 |
| RemoveGrain | rg | u8 | mode=4 | 51.36 | 52.64 | 52.33 | 52.110 | 0.545 |
| RemoveGrain | std | u8 | mode=4 | 56.36 | 56.36 | 56.36 | 56.360 | 0.000 |
| RemoveGrain | zsmooth | u8 | mode=12 | 2439.18 | 2583.96 | 2565.26 | 2529.467 | 64.297 |
| RemoveGrain | rg | u8 | mode=12 | 895.29 | 899.21 | 897.68 | 897.393 | 1.613 |
| RemoveGrain | std | u8 | mode=12 | 152.88 | 153.54 | 152.88 | 153.100 | 0.311 |
| RemoveGrain | zsmooth | u8 | mode=17 | 2464.09 | 2619.24 | 2561.23 | 2548.187 | 64.008 |
| RemoveGrain | rg | u8 | mode=17 | 676 | 684.68 | 684.35 | 681.677 | 4.016 |
| RemoveGrain | zsmooth | u8 | mode=20 | 1936.61 | 2013.28 | 1945.02 | 1964.970 | 34.332 |
| RemoveGrain | rg | u8 | mode=20 | 1821.85 | 2047.38 | 2018.08 | 1962.437 | 100.127 |
| RemoveGrain | std | u8 | mode=20 | 152.53 | 153.33 | 152.93 | 152.930 | 0.327 |
| RemoveGrain | zsmooth | u8 | mode=22 | 1977.21 | 2025.22 | 2010.84 | 2004.423 | 20.118 |
| RemoveGrain | rg | u8 | mode=22 | 580.47 | 583.39 | 583.34 | 582.400 | 1.365 |
| RemoveGrain | zsmooth | u16 | mode=1 | 578.48 | 580.74 | 580.34 | 579.853 | 0.985 |
| RemoveGrain | rg | u16 | mode=1 | 408.65 | 414.03 | 409.58 | 410.753 | 2.348 |
| RemoveGrain | zsmooth | u16 | mode=4 | 488.28 | 489.64 | 488.79 | 488.903 | 0.561 |
| RemoveGrain | rg | u16 | mode=4 | 48.55 | 49.11 | 48.89 | 48.850 | 0.230 |
| RemoveGrain | std | u16 | mode=4 | 53.11 | 53.13 | 53.13 | 53.123 | 0.009 |
| RemoveGrain | zsmooth | u16 | mode=12 | 553.48 | 560.82 | 554.24 | 556.180 | 3.296 |
| RemoveGrain | rg | u16 | mode=12 | 540.97 | 548.97 | 543.73 | 544.557 | 3.318 |
| RemoveGrain | std | u16 | mode=12 | 89.16 | 89.55 | 89.28 | 89.330 | 0.163 |
| RemoveGrain | zsmooth | u16 | mode=17 | 577 | 585.9 | 578.17 | 580.357 | 3.949 |
| RemoveGrain | rg | u16 | mode=17 | 392.2 | 395.89 | 395.09 | 394.393 | 1.585 |
| RemoveGrain | zsmooth | u16 | mode=20 | 396.16 | 398.97 | 396.59 | 397.240 | 1.236 |
| RemoveGrain | rg | u16 | mode=20 | 403.34 | 409.99 | 405.99 | 406.440 | 2.733 |
| RemoveGrain | std | u16 | mode=20 | 88.92 | 89.11 | 88.97 | 89.000 | 0.080 |
| RemoveGrain | zsmooth | u16 | mode=22 | 504 | 507.88 | 504.61 | 505.497 | 1.704 |
| RemoveGrain | rg | u16 | mode=22 | 491.93 | 498.14 | 494.26 | 494.777 | 2.561 |
| RemoveGrain | zsmooth | f32 | mode=1 | 494.55 | 494.95 | 494.73 | 494.743 | 0.164 |
| RemoveGrain | rg | f32 | mode=1 | 497.14 | 512.17 | 497.16 | 502.157 | 7.081 |
| RemoveGrain | zsmooth | f32 | mode=4 | 374.85 | 384.99 | 381.72 | 380.520 | 4.226 |
| RemoveGrain | rg | f32 | mode=4 | 47.16 | 47.76 | 47.48 | 47.467 | 0.245 |
| RemoveGrain | std | f32 | mode=4 | 79.98 | 80.38 | 80.15 | 80.170 | 0.164 |
| RemoveGrain | zsmooth | f32 | mode=12 | 488.36 | 509.22 | 488.54 | 495.373 | 9.791 |
| RemoveGrain | rg | f32 | mode=12 | 331.19 | 340.6 | 334.14 | 335.310 | 3.930 |
| RemoveGrain | std | f32 | mode=12 | 228.36 | 232 | 230.93 | 230.430 | 1.528 |
| RemoveGrain | zsmooth | f32 | mode=17 | 483.71 | 491.95 | 490.37 | 488.677 | 3.571 |
| RemoveGrain | rg | f32 | mode=17 | 473.96 | 482.88 | 478.09 | 478.310 | 3.645 |
| RemoveGrain | zsmooth | f32 | mode=20 | 498.74 | 515.31 | 505.69 | 506.580 | 6.794 |
| RemoveGrain | rg | f32 | mode=20 | 342.16 | 347.46 | 346.96 | 345.527 | 2.389 |
| RemoveGrain | std | f32 | mode=20 | 229.71 | 244.85 | 243 | 239.187 | 6.743 |
| RemoveGrain | zsmooth | f32 | mode=22 | 486.66 | 500.89 | 490.28 | 492.610 | 6.038 |
| RemoveGrain | rg | f32 | mode=22 | 251.24 | 255.42 | 254.65 | 253.770 | 1.816 |
| Repair | zsmooth | u8 | mode=1 | 138.61 | 144.29 | 140.47 | 141.123 | 2.364 |
| Repair | rg | u8 | mode=1 | 121.37 | 124.39 | 124.33 | 123.363 | 1.410 |
| Repair | zsmooth | u8 | mode=12 | 140.87 | 140.99 | 140.9 | 140.920 | 0.051 |
| Repair | rg | u8 | mode=12 | 38.09 | 38.57 | 38.56 | 38.407 | 0.224 |
| Repair | zsmooth | u8 | mode=13 | 136.93 | 140.75 | 140.7 | 139.460 | 1.789 |
| Repair | rg | u8 | mode=13 | 36.95 | 37.19 | 37.04 | 37.060 | 0.099 |
| Repair | zsmooth | u16 | mode=1 | 74.24 | 75.71 | 75.3 | 75.083 | 0.619 |
| Repair | rg | u16 | mode=1 | 70.59 | 71.4 | 71.01 | 71.000 | 0.331 |
| Repair | zsmooth | u16 | mode=12 | 73.33 | 74.37 | 73.82 | 73.840 | 0.425 |
| Repair | rg | u16 | mode=12 | 31.78 | 32.11 | 31.95 | 31.947 | 0.135 |
| Repair | zsmooth | u16 | mode=13 | 72.73 | 73.31 | 72.97 | 73.003 | 0.238 |
| Repair | rg | u16 | mode=13 | 31.27 | 31.54 | 31.5 | 31.437 | 0.119 |
| Repair | zsmooth | f32 | mode=1 | 183.58 | 185 | 183.7 | 184.093 | 0.643 |
| Repair | rg | f32 | mode=1 | 183.66 | 186.13 | 184.41 | 184.733 | 1.034 |
| Repair | zsmooth | f32 | mode=12 | 163.26 | 164.51 | 163.28 | 163.683 | 0.585 |
| Repair | rg | f32 | mode=12 | 40.19 | 40.78 | 40.61 | 40.527 | 0.248 |
| Repair | zsmooth | f32 | mode=13 | 159.88 | 166.31 | 163.81 | 163.333 | 2.647 |
| Repair | rg | f32 | mode=13 | 40.16 | 41.17 | 41.13 | 40.820 | 0.467 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6544.86 | 6566.96 | 6551.59 | 6554.470 | 9.249 |
| TemporalMedian | tmedian | u8 | radius=1 | 93.28 | 93.47 | 93.28 | 93.343 | 0.090 |
| TemporalMedian | zsmooth | u8 | radius=10 | 391.07 | 395.36 | 394.41 | 393.613 | 1.840 |
| TemporalMedian | tmedian | u8 | radius=10 | 16.29 | 17.45 | 17.18 | 16.973 | 0.496 |
| TemporalMedian | zsmooth | u16 | radius=1 | 854.16 | 861.41 | 861.26 | 858.943 | 3.383 |
| TemporalMedian | tmedian | u16 | radius=1 | 85.58 | 87.22 | 86.44 | 86.413 | 0.670 |
| TemporalMedian | zsmooth | u16 | radius=10 | 184.56 | 186.14 | 184.8 | 185.167 | 0.695 |
| TemporalMedian | tmedian | u16 | radius=10 | 18.44 | 18.67 | 18.57 | 18.560 | 0.094 |
| TemporalMedian | zsmooth | f32 | radius=1 | 726.47 | 753.9 | 738.42 | 739.597 | 11.229 |
| TemporalMedian | tmedian | f32 | radius=1 | 76.92 | 79.17 | 78.62 | 78.237 | 0.958 |
| TemporalMedian | zsmooth | f32 | radius=10 | 67.27 | 67.57 | 67.48 | 67.440 | 0.126 |
| TemporalMedian | tmedian | f32 | radius=10 | 21.37 | 21.66 | 21.45 | 21.493 | 0.122 |
| TemporalSoften | zsmooth | u8 | radius=1 | 2859.55 | 2865.1 | 2862.7 | 2862.450 | 2.273 |
| TemporalSoften | std | u8 | radius=1 | 277.06 | 277.15 | 277.1 | 277.103 | 0.037 |
| TemporalSoften | zsmooth | u8 | radius=7 | 607.48 | 611.02 | 608.89 | 609.130 | 1.455 |
| TemporalSoften | std | u8 | radius=7 | 31.91 | 33.03 | 32.35 | 32.430 | 0.461 |
| TemporalSoften | zsmooth | u16 | radius=1 | 541.01 | 543.01 | 542.4 | 542.140 | 0.837 |
| TemporalSoften | std | u16 | radius=1 | 216.28 | 216.73 | 216.56 | 216.523 | 0.186 |
| TemporalSoften | zsmooth | u16 | radius=7 | 231.47 | 232.64 | 231.56 | 231.890 | 0.532 |
| TemporalSoften | std | u16 | radius=7 | 34.41 | 34.53 | 34.5 | 34.480 | 0.051 |
| TemporalSoften | zsmooth | f32 | radius=1 | 434.95 | 442.25 | 441.34 | 439.513 | 3.248 |
| TemporalSoften | std | f32 | radius=1 | 280.32 | 281.89 | 281.4 | 281.203 | 0.656 |
| TemporalSoften | zsmooth | f32 | radius=7 | 76.09 | 76.44 | 76.09 | 76.207 | 0.165 |
| TemporalSoften | std | f32 | radius=7 | 40.69 | 40.74 | 40.72 | 40.717 | 0.021 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 343.95 | 344.59 | 344.41 | 344.317 | 0.269 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 179.31 | 179.83 | 179.32 | 179.487 | 0.243 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 607.23 | 607.74 | 607.61 | 607.527 | 0.216 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 195.48 | 198.71 | 196.56 | 196.917 | 1.343 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 265.84 | 266.58 | 266.55 | 266.323 | 0.342 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 188.43 | 188.54 | 188.47 | 188.480 | 0.045 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 430.1 | 430.8 | 430.68 | 430.527 | 0.306 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 196.96 | 197.69 | 196.98 | 197.210 | 0.340 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 215.53 | 216.75 | 216.35 | 216.210 | 0.508 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 183.7 | 184.68 | 184.62 | 184.333 | 0.449 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 348.42 | 352.09 | 352.07 | 350.860 | 1.725 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 209.2 | 210.74 | 210.26 | 210.067 | 0.643 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 5777.16 | 5911.49 | 5851.33 | 5846.660 | 54.939 |
| VerticalCleaner | rg | u8 | mode=1 | 5829.44 | 5956.7 | 5846.65 | 5877.597 | 56.374 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 2606.96 | 2638.1 | 2620.14 | 2621.733 | 12.763 |
| VerticalCleaner | rg | u8 | mode=2 | 452.98 | 455.48 | 453.86 | 454.107 | 1.035 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 931.49 | 932.85 | 932.06 | 932.133 | 0.558 |
| VerticalCleaner | rg | u16 | mode=1 | 929.76 | 934 | 931.5 | 931.753 | 1.740 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 667.96 | 669.51 | 669.25 | 668.907 | 0.678 |
| VerticalCleaner | rg | u16 | mode=2 | 334.3 | 335.17 | 334.37 | 334.613 | 0.395 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 862.91 | 867.81 | 866.64 | 865.787 | 2.089 |
| VerticalCleaner | rg | f32 | mode=1 | 847.52 | 866.24 | 859.28 | 857.680 | 7.726 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 405.47 | 405.96 | 405.57 | 405.667 | 0.211 |
| VerticalCleaner | rg | f32 | mode=2 | 181.94 | 182.53 | 182.45 | 182.307 | 0.261 |

## 0.10 - Zig 0.14.1 - AVX2
Source: BlankClip YUV420, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

OS: Linux fedora 6.14.9-300.fc42.x86_64 #1 SMP PREEMPT_DYNAMIC Thu May 29 14:27:53 UTC 2025 x86_64 GNU/Linux 

CPU tuning: AVX2 (not znver4 / znver5)

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6693.51 | 6911.04 | 6891.97 | 6832.173 | 98.358 |
| Clense | rg | u8 | function=Clense | 6321.74 | 6356.37 | 6322.03 | 6333.380 | 16.257 |
| Clense | zsmooth | u8 | function=ForwardClense | 6891.25 | 6905.46 | 6898.54 | 6898.417 | 5.802 |
| Clense | rg | u8 | function=ForwardClense | 870.91 | 872.18 | 871.99 | 871.693 | 0.559 |
| Clense | zsmooth | u8 | function=BackwardClense | 6867.77 | 6911.55 | 6897.8 | 6892.373 | 18.280 |
| Clense | rg | u8 | function=BackwardClense | 872.98 | 873.35 | 873.32 | 873.217 | 0.168 |
| Clense | zsmooth | u16 | function=Clense | 1846.42 | 1854.08 | 1849.65 | 1850.050 | 3.140 |
| Clense | rg | u16 | function=Clense | 1468.35 | 1471.57 | 1470.77 | 1470.230 | 1.369 |
| Clense | zsmooth | u16 | function=ForwardClense | 1826.99 | 1828.16 | 1827.18 | 1827.443 | 0.513 |
| Clense | rg | u16 | function=ForwardClense | 545.95 | 546.5 | 546.37 | 546.273 | 0.235 |
| Clense | zsmooth | u16 | function=BackwardClense | 1821.16 | 1833.36 | 1826.04 | 1826.853 | 5.014 |
| Clense | rg | u16 | function=BackwardClense | 547.4 | 547.76 | 547.65 | 547.603 | 0.151 |
| Clense | zsmooth | f32 | function=Clense | 870.41 | 878.25 | 876.06 | 874.907 | 3.303 |
| Clense | rg | f32 | function=Clense | 817.94 | 823.3 | 822.63 | 821.290 | 2.385 |
| Clense | zsmooth | f32 | function=ForwardClense | 879.79 | 881.22 | 881.11 | 880.707 | 0.650 |
| Clense | rg | f32 | function=ForwardClense | 251.25 | 252.24 | 251.68 | 251.723 | 0.405 |
| Clense | zsmooth | f32 | function=BackwardClense | 879.1 | 881.26 | 880.44 | 880.267 | 0.890 |
| Clense | rg | f32 | function=BackwardClense | 251.49 | 251.5 | 251.5 | 251.497 | 0.005 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1460.74 | 1485.51 | 1480.69 | 1475.647 | 10.723 |
| DegrainMedian | dgm | u8 | mode=0 | 178.61 | 178.64 | 178.61 | 178.620 | 0.014 |
| DegrainMedian | zsmooth | u8 | mode=1 | 405.05 | 405.56 | 405.41 | 405.340 | 0.214 |
| DegrainMedian | dgm | u8 | mode=1 | 458.55 | 458.61 | 458.58 | 458.580 | 0.024 |
| DegrainMedian | zsmooth | u8 | mode=2 | 404.93 | 405.41 | 405.13 | 405.157 | 0.197 |
| DegrainMedian | dgm | u8 | mode=2 | 490.83 | 490.93 | 490.91 | 490.890 | 0.043 |
| DegrainMedian | zsmooth | u8 | mode=3 | 431.21 | 431.26 | 431.25 | 431.240 | 0.022 |
| DegrainMedian | dgm | u8 | mode=3 | 517.97 | 518.13 | 518.04 | 518.047 | 0.065 |
| DegrainMedian | zsmooth | u8 | mode=4 | 405.46 | 405.59 | 405.47 | 405.507 | 0.059 |
| DegrainMedian | dgm | u8 | mode=4 | 482.38 | 482.64 | 482.5 | 482.507 | 0.106 |
| DegrainMedian | zsmooth | u8 | mode=5 | 295.97 | 296.13 | 296.07 | 296.057 | 0.066 |
| DegrainMedian | dgm | u8 | mode=5 | 572.21 | 572.41 | 572.32 | 572.313 | 0.082 |
| DegrainMedian | zsmooth | u16 | mode=0 | 604.59 | 608.94 | 607.74 | 607.090 | 1.834 |
| DegrainMedian | dgm | u16 | mode=0 | 85.18 | 85.23 | 85.2 | 85.203 | 0.021 |
| DegrainMedian | zsmooth | u16 | mode=1 | 173.92 | 174.49 | 174.1 | 174.170 | 0.238 |
| DegrainMedian | dgm | u16 | mode=1 | 95.97 | 95.98 | 95.97 | 95.973 | 0.005 |
| DegrainMedian | zsmooth | u16 | mode=2 | 174.48 | 174.96 | 174.49 | 174.643 | 0.224 |
| DegrainMedian | dgm | u16 | mode=2 | 110.16 | 110.24 | 110.18 | 110.193 | 0.034 |
| DegrainMedian | zsmooth | u16 | mode=3 | 183.68 | 183.76 | 183.7 | 183.713 | 0.034 |
| DegrainMedian | dgm | u16 | mode=3 | 126.53 | 126.56 | 126.56 | 126.550 | 0.014 |
| DegrainMedian | zsmooth | u16 | mode=4 | 174.02 | 174.29 | 174.14 | 174.150 | 0.110 |
| DegrainMedian | dgm | u16 | mode=4 | 106.07 | 106.11 | 106.1 | 106.093 | 0.017 |
| DegrainMedian | zsmooth | u16 | mode=5 | 137.59 | 137.61 | 137.6 | 137.600 | 0.008 |
| DegrainMedian | dgm | u16 | mode=5 | 162.48 | 162.57 | 162.55 | 162.533 | 0.039 |
| DegrainMedian | zsmooth | f32 | mode=0 | 240.82 | 241.88 | 241.48 | 241.393 | 0.437 |
| DegrainMedian | zsmooth | f32 | mode=1 | 83.9 | 83.95 | 83.93 | 83.927 | 0.021 |
| DegrainMedian | zsmooth | f32 | mode=2 | 91.49 | 91.61 | 91.58 | 91.560 | 0.051 |
| DegrainMedian | zsmooth | f32 | mode=3 | 94.11 | 94.27 | 94.23 | 94.203 | 0.068 |
| DegrainMedian | zsmooth | f32 | mode=4 | 90.03 | 90.08 | 90.07 | 90.060 | 0.022 |
| DegrainMedian | zsmooth | f32 | mode=5 | 116.23 | 116.39 | 116.33 | 116.317 | 0.066 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1416.01 | 1416.19 | 1416.18 | 1416.127 | 0.083 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1530.12 | 1530.72 | 1530.69 | 1530.510 | 0.276 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 808.25 | 808.52 | 808.3 | 808.357 | 0.117 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 408.63 | 408.85 | 408.67 | 408.717 | 0.096 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 997.37 | 999.35 | 998.48 | 998.400 | 0.810 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.07 | 589.79 | 589.57 | 589.477 | 0.301 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 443.93 | 444.28 | 444.16 | 444.123 | 0.145 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 401.32 | 402.01 | 402 | 401.777 | 0.323 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 795.08 | 809.61 | 809.42 | 804.703 | 6.805 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 384.89 | 392.42 | 391.08 | 389.463 | 3.280 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 1800.81 | 1803.56 | 1802.27 | 1802.213 | 1.123 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 367.4 | 368.7 | 368.44 | 368.180 | 0.562 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 84.06 | 84.16 | 84.14 | 84.120 | 0.043 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 688.12 | 688.75 | 688.39 | 688.420 | 0.258 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 203.02 | 203.18 | 203.06 | 203.087 | 0.068 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 47.79 | 48.31 | 48.03 | 48.043 | 0.212 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 500.12 | 500.39 | 500.16 | 500.223 | 0.119 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 82.89 | 82.93 | 82.9 | 82.907 | 0.017 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 27.48 | 27.56 | 27.53 | 27.523 | 0.033 |
| Median | zsmooth | u8 | radius=1 | 5094.73 | 5107.85 | 5104.25 | 5102.277 | 5.535 |
| Median | std | u8 | radius=1 | 5670.9 | 5701.94 | 5692.93 | 5688.590 | 13.038 |
| Median | ctmf | u8 | radius=1 | 45.64 | 45.68 | 45.67 | 45.663 | 0.017 |
| Median | zsmooth | u8 | radius=2 | 647.61 | 651.24 | 648.86 | 649.237 | 1.506 |
| Median | ctmf | u8 | radius=2 | 872.72 | 875.65 | 874.44 | 874.270 | 1.202 |
| Median | zsmooth | u8 | radius=3 | 150.63 | 150.94 | 150.88 | 150.817 | 0.134 |
| Median | ctmf | u8 | radius=3 | 45.85 | 45.93 | 45.9 | 45.893 | 0.033 |
| Median | zsmooth | u16 | radius=1 | 1637.89 | 1645.97 | 1641.43 | 1641.763 | 3.307 |
| Median | std | u16 | radius=1 | 1725.23 | 1734.13 | 1725.96 | 1728.440 | 4.034 |
| Median | ctmf | u16 | radius=1 | 0.76 | 0.76 | 0.76 | 0.760 | 0.000 |
| Median | zsmooth | u16 | radius=2 | 368.27 | 370.9 | 370.67 | 369.947 | 1.189 |
| Median | ctmf | u16 | radius=2 | 403.79 | 404.31 | 404.17 | 404.090 | 0.220 |
| Median | zsmooth | u16 | radius=3 | 90.07 | 90.13 | 90.1 | 90.100 | 0.024 |
| Median | ctmf | u16 | radius=3 | 0.17 | 0.17 | 0.17 | 0.170 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 707.73 | 711.04 | 710.22 | 709.663 | 1.407 |
| Median | std | f32 | radius=1 | 727.05 | 729.67 | 729.02 | 728.580 | 1.114 |
| Median | zsmooth | f32 | radius=2 | 132.11 | 132.59 | 132.34 | 132.347 | 0.196 |
| Median | ctmf | f32 | radius=2 | 145.92 | 146.19 | 145.99 | 146.033 | 0.114 |
| Median | zsmooth | f32 | radius=3 | 43.53 | 43.57 | 43.57 | 43.557 | 0.019 |
| RemoveGrain | zsmooth | u8 | mode=1 | 5131.34 | 5180.35 | 5141.74 | 5151.143 | 21.084 |
| RemoveGrain | rg | u8 | mode=1 | 1399.25 | 1401.86 | 1401.85 | 1400.987 | 1.228 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3664.48 | 3667.7 | 3666.85 | 3666.343 | 1.363 |
| RemoveGrain | rg | u8 | mode=4 | 894.52 | 906.21 | 900.75 | 900.493 | 4.776 |
| RemoveGrain | std | u8 | mode=4 | 5657.21 | 5680.77 | 5676.43 | 5671.470 | 10.238 |
| RemoveGrain | zsmooth | u8 | mode=12 | 3508.2 | 3522.68 | 3509.02 | 3513.300 | 6.641 |
| RemoveGrain | rg | u8 | mode=12 | 2363.12 | 2370.17 | 2364.37 | 2365.887 | 3.071 |
| RemoveGrain | std | u8 | mode=12 | 1981.59 | 1995.52 | 1986.39 | 1987.833 | 5.778 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4741.83 | 4830.96 | 4755.37 | 4776.053 | 39.216 |
| RemoveGrain | rg | u8 | mode=17 | 1256.21 | 1256.83 | 1256.82 | 1256.620 | 0.290 |
| RemoveGrain | zsmooth | u8 | mode=20 | 3500.36 | 3514.23 | 3511.69 | 3508.760 | 6.030 |
| RemoveGrain | rg | u8 | mode=20 | 772.66 | 773.52 | 773.12 | 773.100 | 0.351 |
| RemoveGrain | std | u8 | mode=20 | 1977.49 | 1987.85 | 1983.62 | 1982.987 | 4.253 |
| RemoveGrain | zsmooth | u8 | mode=22 | 3723.17 | 3733.02 | 3726.62 | 3727.603 | 4.081 |
| RemoveGrain | rg | u8 | mode=22 | 1674.81 | 1683.28 | 1679.22 | 1679.103 | 3.459 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1755.31 | 1757.14 | 1756.66 | 1756.370 | 0.775 |
| RemoveGrain | rg | u16 | mode=1 | 1165.59 | 1167.17 | 1166.25 | 1166.337 | 0.648 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1595.52 | 1613.58 | 1597.34 | 1602.147 | 8.119 |
| RemoveGrain | rg | u16 | mode=4 | 820.74 | 838.53 | 826.66 | 828.643 | 7.397 |
| RemoveGrain | std | u16 | mode=4 | 1721.9 | 1731.99 | 1731.82 | 1728.570 | 4.717 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1326.32 | 1329.5 | 1326.91 | 1327.577 | 1.381 |
| RemoveGrain | rg | u16 | mode=12 | 1478.37 | 1479.58 | 1478.94 | 1478.963 | 0.494 |
| RemoveGrain | std | u16 | mode=12 | 1321.66 | 1324.69 | 1322.25 | 1322.867 | 1.312 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1735.55 | 1745.52 | 1740.25 | 1740.440 | 4.072 |
| RemoveGrain | rg | u16 | mode=17 | 1116.27 | 1118.4 | 1116.63 | 1117.100 | 0.931 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1198.7 | 1204.29 | 1203.94 | 1202.310 | 2.557 |
| RemoveGrain | rg | u16 | mode=20 | 694.68 | 695.29 | 695.2 | 695.057 | 0.269 |
| RemoveGrain | std | u16 | mode=20 | 1322.76 | 1323.16 | 1322.83 | 1322.917 | 0.174 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1484.64 | 1488.77 | 1487.85 | 1487.087 | 1.770 |
| RemoveGrain | rg | u16 | mode=22 | 1443.52 | 1446.5 | 1444.74 | 1444.920 | 1.223 |
| RemoveGrain | zsmooth | f32 | mode=1 | 621.96 | 623.35 | 622.19 | 622.500 | 0.608 |
| RemoveGrain | rg | f32 | mode=1 | 213.58 | 213.64 | 213.6 | 213.607 | 0.025 |
| RemoveGrain | zsmooth | f32 | mode=4 | 466.95 | 468.2 | 467.13 | 467.427 | 0.552 |
| RemoveGrain | rg | f32 | mode=4 | 64.95 | 64.95 | 64.95 | 64.950 | 0.000 |
| RemoveGrain | std | f32 | mode=4 | 725.5 | 728.38 | 728.03 | 727.303 | 1.283 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1115.19 | 1120.08 | 1116.6 | 1117.290 | 2.055 |
| RemoveGrain | rg | f32 | mode=12 | 342.17 | 342.34 | 342.26 | 342.257 | 0.069 |
| RemoveGrain | std | f32 | mode=12 | 1140.4 | 1141.21 | 1140.75 | 1140.787 | 0.332 |
| RemoveGrain | zsmooth | f32 | mode=17 | 679.04 | 679.61 | 679.54 | 679.397 | 0.254 |
| RemoveGrain | rg | f32 | mode=17 | 191.4 | 191.66 | 191.45 | 191.503 | 0.113 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1121.12 | 1125.31 | 1121.95 | 1122.793 | 1.812 |
| RemoveGrain | rg | f32 | mode=20 | 358.42 | 358.82 | 358.7 | 358.647 | 0.168 |
| RemoveGrain | std | f32 | mode=20 | 1138.4 | 1141.81 | 1140.09 | 1140.100 | 1.392 |
| RemoveGrain | zsmooth | f32 | mode=22 | 911.69 | 912.52 | 912.39 | 912.200 | 0.365 |
| RemoveGrain | rg | f32 | mode=22 | 158.72 | 158.78 | 158.75 | 158.750 | 0.024 |
| Repair | zsmooth | u8 | mode=1 | 1469.17 | 1473.3 | 1472.1 | 1471.523 | 1.735 |
| Repair | rg | u8 | mode=1 | 773.91 | 774.58 | 774.11 | 774.200 | 0.281 |
| Repair | zsmooth | u8 | mode=12 | 1307.74 | 1308.57 | 1308.44 | 1308.250 | 0.365 |
| Repair | rg | u8 | mode=12 | 585.16 | 586.82 | 586.05 | 586.010 | 0.678 |
| Repair | zsmooth | u8 | mode=13 | 1298.9 | 1299.36 | 1299.05 | 1299.103 | 0.192 |
| Repair | rg | u8 | mode=13 | 584.45 | 588.12 | 587.49 | 586.687 | 1.602 |
| Repair | zsmooth | u16 | mode=1 | 925.67 | 930.72 | 927.41 | 927.933 | 2.095 |
| Repair | rg | u16 | mode=1 | 723.85 | 725.21 | 724.29 | 724.450 | 0.567 |
| Repair | zsmooth | u16 | mode=12 | 862.63 | 864.65 | 863.51 | 863.597 | 0.827 |
| Repair | rg | u16 | mode=12 | 565.03 | 565.5 | 565.33 | 565.287 | 0.194 |
| Repair | zsmooth | u16 | mode=13 | 861.31 | 864.83 | 862.18 | 862.773 | 1.497 |
| Repair | rg | u16 | mode=13 | 557.77 | 559.33 | 558.56 | 558.553 | 0.637 |
| Repair | zsmooth | f32 | mode=1 | 420.6 | 422.55 | 421.29 | 421.480 | 0.807 |
| Repair | rg | f32 | mode=1 | 173.22 | 173.29 | 173.25 | 173.253 | 0.029 |
| Repair | zsmooth | f32 | mode=12 | 337.08 | 337.79 | 337.2 | 337.357 | 0.310 |
| Repair | rg | f32 | mode=12 | 61.06 | 61.15 | 61.11 | 61.107 | 0.037 |
| Repair | zsmooth | f32 | mode=13 | 337.38 | 338.15 | 338.04 | 337.857 | 0.340 |
| Repair | rg | f32 | mode=13 | 61.23 | 61.38 | 61.26 | 61.290 | 0.065 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6919.52 | 6941.99 | 6925.3 | 6928.937 | 9.527 |
| TemporalMedian | tmedian | u8 | radius=1 | 6117.78 | 6326.85 | 6320.22 | 6254.950 | 97.032 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2328.52 | 2344.31 | 2332.46 | 2335.097 | 6.710 |
| TemporalMedian | zsmooth | u8 | radius=10 | 963.09 | 978.59 | 964.02 | 968.567 | 7.098 |
| TemporalMedian | tmedian | u8 | radius=10 | 20.04 | 20.16 | 20.12 | 20.107 | 0.050 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.83 | 13.86 | 13.84 | 13.843 | 0.012 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1845.48 | 1854.72 | 1849.15 | 1849.783 | 3.799 |
| TemporalMedian | tmedian | u16 | radius=1 | 1699.26 | 1704.12 | 1702.89 | 1702.090 | 2.063 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 930.34 | 938.15 | 932.95 | 933.813 | 3.246 |
| TemporalMedian | zsmooth | u16 | radius=10 | 349.57 | 360.96 | 359.21 | 356.580 | 5.008 |
| TemporalMedian | tmedian | u16 | radius=10 | 16.96 | 17.62 | 16.99 | 17.190 | 0.304 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.71 | 13.72 | 13.71 | 13.713 | 0.005 |
| TemporalMedian | zsmooth | f32 | radius=1 | 892.22 | 901.2 | 892.89 | 895.437 | 4.084 |
| TemporalMedian | tmedian | f32 | radius=1 | 858.49 | 861.33 | 860.67 | 860.163 | 1.214 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 475.44 | 477.02 | 475.5 | 475.987 | 0.731 |
| TemporalMedian | zsmooth | f32 | radius=10 | 186.59 | 187.88 | 186.67 | 187.047 | 0.590 |
| TemporalMedian | tmedian | f32 | radius=10 | 17.6 | 18.05 | 17.85 | 17.833 | 0.184 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.45 | 14.5 | 14.49 | 14.480 | 0.022 |
| TemporalSoften | zsmooth | u8 | radius=1 | 3074.96 | 3079.09 | 3076.19 | 3076.747 | 1.731 |
| TemporalSoften | focus2 | u8 | radius=1 | 1624.57 | 1629.83 | 1628.4 | 1627.600 | 2.221 |
| TemporalSoften | std | u8 | radius=1 | 1681.96 | 1682.87 | 1682.32 | 1682.383 | 0.374 |
| TemporalSoften | zsmooth | u8 | radius=7 | 805.37 | 813.59 | 805.41 | 808.123 | 3.866 |
| TemporalSoften | focus2 | u8 | radius=7 | 435.61 | 436.32 | 435.91 | 435.947 | 0.291 |
| TemporalSoften | std | u8 | radius=7 | 530.02 | 530.24 | 530.06 | 530.107 | 0.096 |
| TemporalSoften | zsmooth | u16 | radius=1 | 955.36 | 955.8 | 955.5 | 955.553 | 0.184 |
| TemporalSoften | focus2 | u16 | radius=1 | 332.49 | 333.86 | 333.78 | 333.377 | 0.628 |
| TemporalSoften | std | u16 | radius=1 | 832.98 | 854.12 | 852.16 | 846.420 | 9.537 |
| TemporalSoften | zsmooth | u16 | radius=7 | 328.29 | 332.18 | 332.04 | 330.837 | 1.802 |
| TemporalSoften | focus2 | u16 | radius=7 | 124.12 | 124.35 | 124.23 | 124.233 | 0.094 |
| TemporalSoften | std | u16 | radius=7 | 316.99 | 324.83 | 319.18 | 320.333 | 3.303 |
| TemporalSoften | zsmooth | f32 | radius=1 | 907.98 | 915.95 | 910.6 | 911.510 | 3.317 |
| TemporalSoften | std | f32 | radius=1 | 606.41 | 611.96 | 611.86 | 610.077 | 2.593 |
| TemporalSoften | zsmooth | f32 | radius=7 | 231.15 | 235.84 | 232.11 | 233.033 | 2.023 |
| TemporalSoften | std | f32 | radius=7 | 204.6 | 210.82 | 207.7 | 207.707 | 2.539 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 335.9 | 336.17 | 335.91 | 335.993 | 0.125 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 160.12 | 163.49 | 163.22 | 162.277 | 1.529 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1131.6 | 1136.19 | 1133.21 | 1133.667 | 1.901 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 196.6 | 197.18 | 197.12 | 196.967 | 0.260 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 329.43 | 329.51 | 329.45 | 329.463 | 0.034 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 153.69 | 155.21 | 154.94 | 154.613 | 0.662 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 753.62 | 763.66 | 763.58 | 760.287 | 4.714 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 184.93 | 185.04 | 184.94 | 184.970 | 0.050 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 226.17 | 226.42 | 226.29 | 226.293 | 0.102 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 154.7 | 155.21 | 155.04 | 154.983 | 0.212 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 878.02 | 882.14 | 881.99 | 880.717 | 1.908 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 177.62 | 178.03 | 177.82 | 177.823 | 0.167 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 10975.05 | 11243.32 | 11015.95 | 11078.107 | 118.011 |
| VerticalCleaner | rg | u8 | mode=1 | 9109.8 | 9234.4 | 9194.5 | 9179.567 | 51.952 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 6999.06 | 7024.49 | 7021 | 7014.850 | 11.256 |
| VerticalCleaner | rg | u8 | mode=2 | 178.84 | 178.87 | 178.85 | 178.853 | 0.012 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2041.61 | 2047.32 | 2041.93 | 2043.620 | 2.620 |
| VerticalCleaner | rg | u16 | mode=1 | 1732.53 | 1734.36 | 1733.56 | 1733.483 | 0.749 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1887.53 | 1890.01 | 1888.88 | 1888.807 | 1.014 |
| VerticalCleaner | rg | u16 | mode=2 | 182.61 | 182.74 | 182.71 | 182.687 | 0.056 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1307.15 | 1318.64 | 1315.59 | 1313.793 | 4.860 |
| VerticalCleaner | rg | f32 | mode=1 | 1273.65 | 1286.26 | 1276.44 | 1278.783 | 5.408 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 670.38 | 670.72 | 670.42 | 670.507 | 0.152 |
| VerticalCleaner | rg | f32 | mode=2 | 92.22 | 92.25 | 92.22 | 92.230 | 0.014 |

## 0.9 - Zig 0.14.0 - ARM NEON (aarch64-macos)
Source: BlankClip YUV420, 1920x1080

Machine: M4 Mac Mini, 16GB

CPU tuning: aarch64-macos

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6731.19 | 6739.47 | 6737.23 | 6735.963333333333 | 3.4969446981935133 |
| Clense | rg | u8 | function=Clense | 6610.5 | 6625.5 | 6623.49 | 6619.829999999999 | 6.648142597748596 |
| Clense | zsmooth | u8 | function=ForwardClense | 6118.75 | 6182.43 | 6120.09 | 6140.423333333333 | 29.70823604472159 |
| Clense | rg | u8 | function=ForwardClense | 1267.74 | 1271.18 | 1269.91 | 1269.61 | 1.420305131535734 |
| Clense | zsmooth | u8 | function=BackwardClense | 6186.17 | 6237.93 | 6189.86 | 6204.653333333333 | 23.578329504488458 |
| Clense | rg | u8 | function=BackwardClense | 1268.85 | 1270.89 | 1269.67 | 1269.8033333333333 | 0.838146102352694 |
| Clense | zsmooth | u16 | function=Clense | 1027.6 | 1028.61 | 1028.44 | 1028.2166666666665 | 0.44153771702491607 |
| Clense | rg | u16 | function=Clense | 1018.82 | 1026.88 | 1020.92 | 1022.2066666666666 | 3.4139452576487637 |
| Clense | zsmooth | u16 | function=ForwardClense | 1018.97 | 1025.31 | 1024.78 | 1023.02 | 2.8719447534147444 |
| Clense | rg | u16 | function=ForwardClense | 724.84 | 726.6 | 725.12 | 725.52 | 0.7721830525637476 |
| Clense | zsmooth | u16 | function=BackwardClense | 1019.86 | 1028.03 | 1022.4 | 1023.43 | 3.4139810583344725 |
| Clense | rg | u16 | function=BackwardClense | 725.8 | 729.14 | 728.32 | 727.7533333333332 | 1.4212044969751143 |
| Clense | zsmooth | f32 | function=Clense | 734.89 | 747.27 | 737.54 | 739.9 | 5.322486887411436 |
| Clense | rg | f32 | function=Clense | 721.87 | 738.72 | 730.86 | 730.4833333333332 | 6.884137967498595 |
| Clense | zsmooth | f32 | function=ForwardClense | 723.28 | 760.92 | 739.94 | 741.38 | 15.4001645012859 |
| Clense | rg | f32 | function=ForwardClense | 381.48 | 381.94 | 381.7 | 381.7066666666667 | 0.18785337071473016 |
| Clense | zsmooth | f32 | function=BackwardClense | 730.57 | 761.54 | 756.36 | 749.4900000000001 | 13.544565946041454 |
| Clense | rg | f32 | function=BackwardClense | 380.75 | 382.27 | 382.01 | 381.6766666666667 | 0.6637938100210133 |
| DegrainMedian | zsmooth | u8 | mode=0 | 779.55 | 783.91 | 781.86 | 781.7733333333332 | 1.781017187514552 |
| DegrainMedian | dgm | u8 | mode=0 | 157.22 | 157.72 | 157.58 | 157.50666666666666 | 0.2106075866524191 |
| DegrainMedian | zsmooth | u8 | mode=1 | 222.61 | 222.74 | 222.67 | 222.67333333333332 | 0.05312459150169607 |
| DegrainMedian | dgm | u8 | mode=1 | 85.08 | 85.11 | 85.09 | 85.09333333333335 | 0.012472191289246521 |
| DegrainMedian | zsmooth | u8 | mode=2 | 222.25 | 222.55 | 222.46 | 222.42 | 0.12569805089977013 |
| DegrainMedian | dgm | u8 | mode=2 | 85.05 | 85.2 | 85.11 | 85.12 | 0.0616441400296921 |
| DegrainMedian | zsmooth | u8 | mode=3 | 237.4 | 238.24 | 238.04 | 237.89333333333335 | 0.35826743580118336 |
| DegrainMedian | dgm | u8 | mode=3 | 88.22 | 88.55 | 88.47 | 88.41333333333334 | 0.1405544576153862 |
| DegrainMedian | zsmooth | u8 | mode=4 | 222.8 | 223.44 | 223 | 223.08 | 0.2673325020768406 |
| DegrainMedian | dgm | u8 | mode=4 | 83.86 | 84.12 | 84.06 | 84.01333333333334 | 0.11115554667022248 |
| DegrainMedian | zsmooth | u8 | mode=5 | 217.61 | 218.05 | 217.66 | 217.7733333333333 | 0.1966949132257613 |
| DegrainMedian | dgm | u8 | mode=5 | 112.9 | 113.25 | 113.17 | 113.10666666666667 | 0.14974051630143898 |
| DegrainMedian | zsmooth | u16 | mode=0 | 252.75 | 253.91 | 253.03 | 253.23 | 0.494233413142682 |
| DegrainMedian | dgm | u16 | mode=0 | 144.61 | 144.92 | 144.75 | 144.76 | 0.12675435561219964 |
| DegrainMedian | zsmooth | u16 | mode=1 | 101.21 | 101.39 | 101.34 | 101.31333333333333 | 0.07586537784494371 |
| DegrainMedian | dgm | u16 | mode=1 | 83.78 | 84 | 83.98 | 83.92 | 0.09933109617167586 |
| DegrainMedian | zsmooth | u16 | mode=2 | 101.07 | 101.37 | 101.18 | 101.20666666666666 | 0.12391753530294472 |
| DegrainMedian | dgm | u16 | mode=2 | 83.45 | 83.61 | 83.49 | 83.51666666666667 | 0.06798692684790328 |
| DegrainMedian | zsmooth | u16 | mode=3 | 107.65 | 107.95 | 107.75 | 107.78333333333335 | 0.12472191289246395 |
| DegrainMedian | dgm | u16 | mode=3 | 88.46 | 88.55 | 88.51 | 88.50666666666666 | 0.03681787005729255 |
| DegrainMedian | zsmooth | u16 | mode=4 | 100.96 | 100.99 | 100.96 | 100.96999999999998 | 0.014142135623731487 |
| DegrainMedian | dgm | u16 | mode=4 | 83.43 | 83.77 | 83.43 | 83.54333333333334 | 0.16027753706894565 |
| DegrainMedian | zsmooth | u16 | mode=5 | 97.68 | 97.75 | 97.73 | 97.72000000000001 | 0.029439202887756852 |
| DegrainMedian | dgm | u16 | mode=5 | 103.59 | 103.75 | 103.68 | 103.67333333333333 | 0.06548960901462712 |
| DegrainMedian | zsmooth | f32 | mode=0 | 131.49 | 132.8 | 132.55 | 132.28 | 0.5678614854580893 |
| DegrainMedian | zsmooth | f32 | mode=1 | 72.91 | 73.24 | 73.11 | 73.08666666666666 | 0.1357284871433484 |
| DegrainMedian | zsmooth | f32 | mode=2 | 79.93 | 80.34 | 80.32 | 80.19666666666667 | 0.18873850222522373 |
| DegrainMedian | zsmooth | f32 | mode=3 | 84.28 | 84.39 | 84.3 | 84.32333333333332 | 0.047842333648024794 |
| DegrainMedian | zsmooth | f32 | mode=4 | 79.68 | 79.93 | 79.78 | 79.79666666666667 | 0.10274023338281658 |
| DegrainMedian | zsmooth | f32 | mode=5 | 99.78 | 100.27 | 99.82 | 99.95666666666666 | 0.222161102706021 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1502.04 | 1505.96 | 1505.64 | 1504.5466666666669 | 1.7772888216482214 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 586.17 | 589.51 | 587.52 | 587.7333333333333 | 1.3718681504511492 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 670.99 | 673.41 | 673 | 672.4666666666667 | 1.0574917914049546 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 303.41 | 304.08 | 303.42 | 303.6366666666667 | 0.31351058816071603 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 644.31 | 646.81 | 645.87 | 645.6633333333333 | 1.0310296902719291 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 404.81 | 406.34 | 405.23 | 405.46 | 0.6454455825241827 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 348.85 | 349.88 | 349.69 | 349.47333333333336 | 0.4475364665464457 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 238.79 | 239.56 | 239.22 | 239.18999999999997 | 0.31506613062446004 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 536.77 | 546.22 | 539.75 | 540.9133333333333 | 3.944670103091305 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 215.31 | 217.04 | 215.84 | 216.0633333333333 | 0.723709579565967 |
| InterQuartileMean | zsmooth | u8 |  | 300.45 | 330.09 | 311.48 | 314.00666666666666 | 12.23166473633994 |
| InterQuartileMean | zsmooth | u16 |  | 306.64 | 319.17 | 306.74 | 310.84999999999997 | 5.883270065759923 |
| InterQuartileMean | zsmooth | f32 |  | 213.11 | 221.8 | 219.86 | 218.25666666666666 | 3.724426876118734 |
| RemoveGrain | zsmooth | u8 | mode=1 | 2492.29 | 2719.27 | 2641.06 | 2617.5400000000004 | 94.14482779207789 |
| RemoveGrain | rg | u8 | mode=1 | 735.19 | 740.05 | 737.06 | 737.4333333333334 | 2.001571604736823 |
| RemoveGrain | zsmooth | u8 | mode=4 | 1839.56 | 1893.23 | 1859.6 | 1864.1299999999999 | 22.143590494768493 |
| RemoveGrain | rg | u8 | mode=4 | 52.69 | 53.81 | 53.4 | 53.300000000000004 | 0.46267339092135856 |
| RemoveGrain | std | u8 | mode=4 | 48.67 | 48.68 | 48.68 | 48.67666666666667 | 0.004714045207909379 |
| RemoveGrain | zsmooth | u8 | mode=12 | 2564.54 | 2732.1 | 2706.04 | 2667.56 | 73.61893415872484 |
| RemoveGrain | rg | u8 | mode=12 | 901.69 | 920.21 | 912.6 | 911.5 | 7.600662251847963 |
| RemoveGrain | std | u8 | mode=12 | 154.85 | 156.28 | 155.38 | 155.50333333333333 | 0.5902730065166674 |
| RemoveGrain | zsmooth | u8 | mode=17 | 2404.53 | 2660.67 | 2487.17 | 2517.456666666667 | 106.73920408588815 |
| RemoveGrain | rg | u8 | mode=17 | 697.55 | 698.64 | 697.59 | 697.9266666666666 | 0.5046671070011267 |
| RemoveGrain | zsmooth | u8 | mode=20 | 1617.84 | 1891.59 | 1867.44 | 1792.29 | 123.74815150134569 |
| RemoveGrain | rg | u8 | mode=20 | 1765.2 | 1864.52 | 1780.26 | 1803.3266666666666 | 43.70483522703432 |
| RemoveGrain | std | u8 | mode=20 | 149.61 | 153.74 | 151.82 | 151.72333333333333 | 1.6874504107940125 |
| RemoveGrain | zsmooth | u8 | mode=22 | 1999.87 | 2053.2 | 2020.37 | 2024.4799999999998 | 21.964991843082146 |
| RemoveGrain | rg | u8 | mode=22 | 589.85 | 590.9 | 590.8 | 590.5166666666668 | 0.4731689855525871 |
| RemoveGrain | zsmooth | u16 | mode=1 | 642.42 | 652.24 | 650.62 | 648.4266666666666 | 4.2985372188946345 |
| RemoveGrain | rg | u16 | mode=1 | 447.52 | 452.56 | 450.58 | 450.21999999999997 | 2.0732583051805276 |
| RemoveGrain | zsmooth | u16 | mode=4 | 537.12 | 545.66 | 543.34 | 542.04 | 3.605588255287423 |
| RemoveGrain | rg | u16 | mode=4 | 49.35 | 49.61 | 49.43 | 49.46333333333333 | 0.10873004286866655 |
| RemoveGrain | std | u16 | mode=4 | 47.92 | 47.96 | 47.96 | 47.946666666666665 | 0.018856180831640864 |
| RemoveGrain | zsmooth | u16 | mode=12 | 618.21 | 625.35 | 622.53 | 622.0300000000001 | 2.936256119618987 |
| RemoveGrain | rg | u16 | mode=12 | 604.86 | 606.62 | 606.55 | 606.0099999999999 | 0.8136747917114316 |
| RemoveGrain | std | u16 | mode=12 | 92.63 | 93.03 | 92.99 | 92.88333333333333 | 0.17987650084309534 |
| RemoveGrain | zsmooth | u16 | mode=17 | 650.42 | 655.39 | 654.31 | 653.3733333333333 | 2.13435912837763 |
| RemoveGrain | rg | u16 | mode=17 | 428.61 | 432.67 | 432.64 | 431.3066666666667 | 1.9068706184624937 |
| RemoveGrain | zsmooth | u16 | mode=20 | 422.38 | 425.09 | 423.44 | 423.6366666666666 | 1.115058543555241 |
| RemoveGrain | rg | u16 | mode=20 | 436.39 | 440.1 | 438.51 | 438.3333333333333 | 1.5197441305108783 |
| RemoveGrain | std | u16 | mode=20 | 93.05 | 93.4 | 93.36 | 93.27 | 0.15641824275533703 |
| RemoveGrain | zsmooth | u16 | mode=22 | 556.13 | 564.84 | 558.3 | 559.7566666666667 | 3.702020469359363 |
| RemoveGrain | rg | u16 | mode=22 | 544.74 | 551.77 | 549.09 | 548.5333333333333 | 2.896852698284037 |
| RemoveGrain | zsmooth | f32 | mode=1 | 500.22 | 522.9 | 514.06 | 512.3933333333333 | 9.33377141829006 |
| RemoveGrain | rg | f32 | mode=1 | 501.58 | 503.1 | 502.39 | 502.35666666666674 | 0.6209848808322481 |
| RemoveGrain | zsmooth | f32 | mode=4 | 382.22 | 388.16 | 387.15 | 385.8433333333333 | 2.595050845145205 |
| RemoveGrain | rg | f32 | mode=4 | 47.31 | 48.42 | 47.88 | 47.870000000000005 | 0.4532107677449862 |
| RemoveGrain | std | f32 | mode=4 | 68.65 | 69.1 | 68.85 | 68.86666666666666 | 0.18408935028644988 |
| RemoveGrain | zsmooth | f32 | mode=12 | 498.62 | 519.06 | 511.11 | 509.59666666666664 | 8.41292788246489 |
| RemoveGrain | rg | f32 | mode=12 | 340.46 | 345.67 | 341.85 | 342.66 | 2.202740717076505 |
| RemoveGrain | std | f32 | mode=12 | 223.81 | 242.93 | 233.71 | 233.48333333333335 | 7.80735265986849 |
| RemoveGrain | zsmooth | f32 | mode=17 | 487.82 | 496.55 | 492.34 | 492.2366666666667 | 3.5647564978395003 |
| RemoveGrain | rg | f32 | mode=17 | 481.98 | 496.54 | 483.18 | 487.23333333333335 | 6.599016761777642 |
| RemoveGrain | zsmooth | f32 | mode=20 | 499.21 | 501.58 | 501.18 | 500.6566666666667 | 1.0359000380774688 |
| RemoveGrain | rg | f32 | mode=20 | 345.65 | 355.61 | 350.45 | 350.57 | 4.067038234391228 |
| RemoveGrain | std | f32 | mode=20 | 237.43 | 242.58 | 239.77 | 239.9266666666667 | 2.1053951859185243 |
| RemoveGrain | zsmooth | f32 | mode=22 | 499.12 | 510.95 | 508.31 | 506.1266666666667 | 5.070334198934902 |
| RemoveGrain | rg | f32 | mode=22 | 256.36 | 263.38 | 256.46 | 258.7333333333333 | 3.2859431252263356 |
| Repair | zsmooth | u8 | mode=1 | 135.51 | 149.15 | 139.32 | 141.32666666666668 | 5.746444311243458 |
| Repair | rg | u8 | mode=1 | 128.41 | 128.79 | 128.67 | 128.62333333333333 | 0.1586050300449351 |
| Repair | zsmooth | u8 | mode=12 | 135.12 | 146.22 | 144.61 | 141.98333333333335 | 4.897416552519185 |
| Repair | rg | u8 | mode=12 | 38.88 | 39.85 | 39.62 | 39.449999999999996 | 0.4138437708443439 |
| Repair | zsmooth | u8 | mode=13 | 145.37 | 145.82 | 145.48 | 145.55666666666667 | 0.19154343864744533 |
| Repair | rg | u8 | mode=13 | 36.33 | 39.01 | 36.95 | 37.43 | 1.1455420841971127 |
| Repair | zsmooth | u16 | mode=1 | 77 | 79.25 | 78.03 | 78.09333333333333 | 0.9196496917607027 |
| Repair | rg | u16 | mode=1 | 73.74 | 74.32 | 74.2 | 74.08666666666666 | 0.24997777679003633 |
| Repair | zsmooth | u16 | mode=12 | 75.65 | 76.3 | 75.66 | 75.87 | 0.3040833219146777 |
| Repair | rg | u16 | mode=12 | 32.79 | 32.95 | 32.87 | 32.87 | 0.06531972647421959 |
| Repair | zsmooth | u16 | mode=13 | 75.5 | 76.17 | 75.57 | 75.74666666666667 | 0.3007028803025064 |
| Repair | rg | u16 | mode=13 | 32.04 | 32.54 | 32.13 | 32.23666666666667 | 0.2176133165859923 |
| Repair | zsmooth | f32 | mode=1 | 176.53 | 190.07 | 183.34 | 183.31333333333336 | 5.527714014149265 |
| Repair | rg | f32 | mode=1 | 180.52 | 185.01 | 180.75 | 182.09333333333333 | 2.0645311547392207 |
| Repair | zsmooth | f32 | mode=12 | 163.51 | 167.28 | 163.91 | 164.89999999999998 | 1.6908183423025311 |
| Repair | rg | f32 | mode=12 | 41.35 | 41.73 | 41.46 | 41.51333333333333 | 0.1596524001977053 |
| Repair | zsmooth | f32 | mode=13 | 163.83 | 169.51 | 169.35 | 167.56333333333333 | 2.640673314811112 |
| Repair | rg | f32 | mode=13 | 40.88 | 41.12 | 41.1 | 41.03333333333333 | 0.10873004286866567 |
| TemporalMedian | zsmooth | u8 | radius=1 | 5754.52 | 5792.26 | 5789.54 | 5778.7733333333335 | 17.18560896667762 |
| TemporalMedian | tmedian | u8 | radius=1 | 96.25 | 101.88 | 97.91 | 98.67999999999999 | 2.362047134725863 |
| TemporalMedian | zsmooth | u8 | radius=10 | 320.04 | 334.22 | 331.31 | 328.52333333333337 | 6.115130597315336 |
| TemporalMedian | tmedian | u8 | radius=10 | 16.47 | 17.52 | 16.67 | 16.886666666666667 | 0.455216676124922 |
| TemporalMedian | zsmooth | u16 | radius=1 | 960.94 | 968.27 | 962.55 | 963.9200000000001 | 3.1453563656073293 |
| TemporalMedian | tmedian | u16 | radius=1 | 85.33 | 86.51 | 85.42 | 85.75333333333333 | 0.5363042254376007 |
| TemporalMedian | zsmooth | u16 | radius=10 | 174.65 | 178.16 | 177.84 | 176.88333333333333 | 1.5845994937382588 |
| TemporalMedian | tmedian | u16 | radius=10 | 18.73 | 18.78 | 18.75 | 18.753333333333334 | 0.020548046676563587 |
| TemporalMedian | zsmooth | f32 | radius=1 | 707.75 | 718.4 | 712.39 | 712.8466666666667 | 4.359819058426868 |
| TemporalMedian | tmedian | f32 | radius=1 | 80.59 | 82.5 | 80.79 | 81.29333333333334 | 0.857139947085005 |
| TemporalMedian | zsmooth | f32 | radius=10 | 62.54 | 62.7 | 62.65 | 62.629999999999995 | 0.06683312551921264 |
| TemporalMedian | tmedian | f32 | radius=10 | 21.58 | 21.88 | 21.85 | 21.77 | 0.13490737563232122 |
| TemporalSoften | zsmooth | u8 | radius=1 | 2872.15 | 2879.59 | 2873.62 | 2875.1200000000003 | 3.2172348375585456 |
| TemporalSoften | std | u8 | radius=1 | 232.6 | 242.38 | 238.07 | 237.6833333333333 | 4.002018934932162 |
| TemporalSoften | zsmooth | u8 | radius=7 | 611.98 | 613.11 | 612.68 | 612.59 | 0.4656894530335221 |
| TemporalSoften | std | u8 | radius=7 | 32.35 | 33.23 | 32.99 | 32.85666666666666 | 0.37142368739157505 |
| TemporalSoften | zsmooth | u16 | radius=1 | 594.63 | 596.45 | 595.7 | 595.5933333333334 | 0.7468303392040174 |
| TemporalSoften | std | u16 | radius=1 | 221.69 | 222.2 | 222.08 | 221.99 | 0.2177154105707715 |
| TemporalSoften | zsmooth | u16 | radius=7 | 239.46 | 241.42 | 240.37 | 240.41666666666666 | 0.8008467740807489 |
| TemporalSoften | std | u16 | radius=7 | 34.81 | 34.84 | 34.83 | 34.82666666666667 | 0.012472191289246521 |
| TemporalSoften | zsmooth | f32 | radius=1 | 694.45 | 715.16 | 699.7 | 703.1033333333334 | 8.790640224440706 |
| TemporalSoften | std | f32 | radius=1 | 276.78 | 281.31 | 281.02 | 279.7033333333333 | 2.0704964514713846 |
| TemporalSoften | zsmooth | f32 | radius=7 | 170.99 | 171.82 | 171.72 | 171.51 | 0.369954952212647 |
| TemporalSoften | std | f32 | radius=7 | 40.76 | 40.94 | 40.83 | 40.843333333333334 | 0.07408703590297609 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 328.92 | 329.43 | 329.36 | 329.2366666666667 | 0.22573337271115718 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 178.41 | 180.32 | 179.1 | 179.27666666666664 | 0.7896975511056243 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 580.84 | 581.08 | 581.01 | 580.9766666666666 | 0.10077477638553842 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 197.12 | 198.33 | 197.57 | 197.67333333333332 | 0.4993551397107672 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 280.77 | 281.26 | 280.89 | 280.9733333333333 | 0.2085398975948976 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 192.9 | 193.69 | 193.13 | 193.24 | 0.3317629675938305 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 451.23 | 453.1 | 451.89 | 452.0733333333333 | 0.77435277633791 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 202.77 | 203.65 | 202.9 | 203.10666666666668 | 0.38784303812524623 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 264.38 | 267.3 | 266.21 | 265.9633333333333 | 1.204777526719726 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 181.62 | 183.77 | 182.21 | 182.53333333333333 | 0.9070219891981081 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 523.06 | 531.11 | 528.67 | 527.6133333333333 | 3.3702654033308796 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 206.3 | 207.91 | 207.28 | 207.16333333333333 | 0.662436579773652 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 6043.93 | 6330.33 | 6148.05 | 6174.103333333333 | 118.3647530118469 |
| VerticalCleaner | rg | u8 | mode=1 | 5813.31 | 5953.04 | 5918.2 | 5894.849999999999 | 59.38594165849894 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 2645.48 | 2695.21 | 2678.1 | 2672.93 | 20.62870007214867 |
| VerticalCleaner | rg | u8 | mode=2 | 456.99 | 459.57 | 458.47 | 458.3433333333333 | 1.057081937326625 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 1100.72 | 1106.35 | 1105.95 | 1104.34 | 2.5649301484965488 |
| VerticalCleaner | rg | u16 | mode=1 | 1092.67 | 1099.61 | 1097.27 | 1096.5166666666667 | 2.882884358107661 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 761.71 | 765.02 | 764.49 | 763.7400000000001 | 1.4516427476023868 |
| VerticalCleaner | rg | u16 | mode=2 | 358.1 | 359.29 | 358.87 | 358.75333333333333 | 0.4927699485786648 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 843.66 | 862.75 | 859.61 | 855.34 | 8.357898459939971 |
| VerticalCleaner | rg | f32 | mode=1 | 865.66 | 875.54 | 874.13 | 871.7766666666666 | 4.363273490804305 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 414.03 | 418.06 | 414.95 | 415.68 | 1.724316289625168 |
| VerticalCleaner | rg | f32 | mode=2 | 185.28 | 185.93 | 185.43 | 185.5466666666667 | 0.27788886667555296 |

## 0.9 - Zig 0.14.0 - AVX512 (znver4)
Source: BlankClip YUV420, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

CPU tuning: AVX512

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6514.08 | 6987.13 | 6834.93 | 6778.713 | 197.171 |
| Clense | rg | u8 | function=Clense | 6329.87 | 6363.84 | 6343.05 | 6345.587 | 13.984 |
| Clense | zsmooth | u8 | function=ForwardClense | 6847.98 | 6893.89 | 6858.84 | 6866.903 | 19.591 |
| Clense | rg | u8 | function=ForwardClense | 868.15 | 870.9 | 870.09 | 869.713 | 1.154 |
| Clense | zsmooth | u8 | function=BackwardClense | 6817.33 | 6884.37 | 6850.76 | 6850.820 | 27.369 |
| Clense | rg | u8 | function=BackwardClense | 871.61 | 872.81 | 872.79 | 872.403 | 0.561 |
| Clense | zsmooth | u16 | function=Clense | 1862.08 | 1874.98 | 1869.14 | 1868.733 | 5.274 |
| Clense | rg | u16 | function=Clense | 1461.1 | 1465.35 | 1464.26 | 1463.570 | 1.802 |
| Clense | zsmooth | u16 | function=ForwardClense | 1822.74 | 1837.21 | 1830.1 | 1830.017 | 5.908 |
| Clense | rg | u16 | function=ForwardClense | 545.07 | 546.56 | 545.79 | 545.807 | 0.608 |
| Clense | zsmooth | u16 | function=BackwardClense | 1835.8 | 1844.58 | 1844.3 | 1841.560 | 4.075 |
| Clense | rg | u16 | function=BackwardClense | 546.51 | 547.13 | 546.79 | 546.810 | 0.254 |
| Clense | zsmooth | f32 | function=Clense | 869.36 | 870.16 | 869.42 | 869.647 | 0.364 |
| Clense | rg | f32 | function=Clense | 799.36 | 809.12 | 801.5 | 803.327 | 4.189 |
| Clense | zsmooth | f32 | function=ForwardClense | 864.3 | 872.93 | 872.28 | 869.837 | 3.924 |
| Clense | rg | f32 | function=ForwardClense | 251.1 | 251.98 | 251.43 | 251.503 | 0.363 |
| Clense | zsmooth | f32 | function=BackwardClense | 871.25 | 877.27 | 873.79 | 874.103 | 2.468 |
| Clense | rg | f32 | function=BackwardClense | 250.04 | 250.37 | 250.26 | 250.223 | 0.137 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1856.92 | 1872.34 | 1870.95 | 1866.737 | 6.965 |
| DegrainMedian | dgm | u8 | mode=0 | 178.59 | 178.72 | 178.64 | 178.650 | 0.054 |
| DegrainMedian | zsmooth | u8 | mode=1 | 768.86 | 771.65 | 770.06 | 770.190 | 1.143 |
| DegrainMedian | dgm | u8 | mode=1 | 456.96 | 458.39 | 457.54 | 457.630 | 0.587 |
| DegrainMedian | zsmooth | u8 | mode=2 | 774.37 | 779.07 | 774.42 | 775.953 | 2.204 |
| DegrainMedian | dgm | u8 | mode=2 | 491.35 | 491.43 | 491.43 | 491.403 | 0.038 |
| DegrainMedian | zsmooth | u8 | mode=3 | 789.24 | 796.07 | 793.34 | 792.883 | 2.807 |
| DegrainMedian | dgm | u8 | mode=3 | 518.29 | 518.53 | 518.42 | 518.413 | 0.098 |
| DegrainMedian | zsmooth | u8 | mode=4 | 781.5 | 782.58 | 782.05 | 782.043 | 0.441 |
| DegrainMedian | dgm | u8 | mode=4 | 483.04 | 483.09 | 483.05 | 483.060 | 0.022 |
| DegrainMedian | zsmooth | u8 | mode=5 | 539.76 | 540.79 | 539.94 | 540.163 | 0.449 |
| DegrainMedian | dgm | u8 | mode=5 | 573.28 | 573.79 | 573.74 | 573.603 | 0.230 |
| DegrainMedian | zsmooth | u16 | mode=0 | 762.31 | 766.1 | 762.51 | 763.640 | 1.741 |
| DegrainMedian | dgm | u16 | mode=0 | 85.3 | 85.35 | 85.32 | 85.323 | 0.021 |
| DegrainMedian | zsmooth | u16 | mode=1 | 324.68 | 325.53 | 325.41 | 325.207 | 0.376 |
| DegrainMedian | dgm | u16 | mode=1 | 96.07 | 96.09 | 96.08 | 96.080 | 0.008 |
| DegrainMedian | zsmooth | u16 | mode=2 | 324.56 | 325.24 | 325.17 | 324.990 | 0.305 |
| DegrainMedian | dgm | u16 | mode=2 | 110.31 | 110.35 | 110.33 | 110.330 | 0.016 |
| DegrainMedian | zsmooth | u16 | mode=3 | 331.22 | 331.59 | 331.46 | 331.423 | 0.153 |
| DegrainMedian | dgm | u16 | mode=3 | 126.66 | 126.68 | 126.67 | 126.670 | 0.008 |
| DegrainMedian | zsmooth | u16 | mode=4 | 314.89 | 315.36 | 314.9 | 315.050 | 0.219 |
| DegrainMedian | dgm | u16 | mode=4 | 106.17 | 106.18 | 106.18 | 106.177 | 0.005 |
| DegrainMedian | zsmooth | u16 | mode=5 | 244.16 | 244.32 | 244.22 | 244.233 | 0.066 |
| DegrainMedian | dgm | u16 | mode=5 | 162.86 | 162.93 | 162.9 | 162.897 | 0.029 |
| DegrainMedian | zsmooth | f32 | mode=0 | 365.61 | 366.8 | 366.4 | 366.270 | 0.494 |
| DegrainMedian | zsmooth | f32 | mode=1 | 140.71 | 141.63 | 141.04 | 141.127 | 0.381 |
| DegrainMedian | zsmooth | f32 | mode=2 | 142.57 | 146.66 | 144.15 | 144.460 | 1.684 |
| DegrainMedian | zsmooth | f32 | mode=3 | 143.07 | 145.51 | 145.19 | 144.590 | 1.083 |
| DegrainMedian | zsmooth | f32 | mode=4 | 141.16 | 141.9 | 141.75 | 141.603 | 0.319 |
| DegrainMedian | zsmooth | f32 | mode=5 | 177.75 | 178.72 | 178.09 | 178.187 | 0.402 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 3311.06 | 3318.56 | 3311.62 | 3313.747 | 3.411 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1532.08 | 1534.1 | 1532.26 | 1532.813 | 0.913 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 1632.04 | 1635.14 | 1634.47 | 1633.883 | 1.332 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 409.14 | 409.32 | 409.25 | 409.237 | 0.074 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 1564.43 | 1565.35 | 1564.54 | 1564.773 | 0.410 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.52 | 589.99 | 589.86 | 589.790 | 0.198 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 784.97 | 802.78 | 802.15 | 796.633 | 8.251 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 401.3 | 402.07 | 402.03 | 401.800 | 0.354 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 857.32 | 865.83 | 864.11 | 862.420 | 3.674 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 531.86 | 534.46 | 532.55 | 532.957 | 1.100 |
| InterQuartileMean | zsmooth | u8 |  | 1674.82 | 1675.95 | 1675.22 | 1675.330 | 0.468 |
| InterQuartileMean | zsmooth | u16 |  | 992.75 | 994.3 | 994.19 | 993.747 | 0.706 |
| InterQuartileMean | zsmooth | f32 |  | 507.17 | 507.6 | 507.59 | 507.453 | 0.200 |
| RemoveGrain | zsmooth | u8 | mode=1 | 4500.94 | 4531.75 | 4512.55 | 4515.080 | 12.705 |
| RemoveGrain | rg | u8 | mode=1 | 1400.03 | 1401.31 | 1400.58 | 1400.640 | 0.524 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3188.56 | 3193.3 | 3190.03 | 3190.630 | 1.981 |
| RemoveGrain | rg | u8 | mode=4 | 907.72 | 925.18 | 908.78 | 913.893 | 7.993 |
| RemoveGrain | std | u8 | mode=4 | 5637.87 | 5755.1 | 5641.33 | 5678.100 | 54.466 |
| RemoveGrain | zsmooth | u8 | mode=12 | 5442.21 | 5513.11 | 5464.66 | 5473.327 | 29.586 |
| RemoveGrain | rg | u8 | mode=12 | 2366.49 | 2386.47 | 2382.97 | 2378.643 | 8.712 |
| RemoveGrain | std | u8 | mode=12 | 1989.65 | 1998.73 | 1994.81 | 1994.397 | 3.718 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4129.12 | 4143.33 | 4137.74 | 4136.730 | 5.845 |
| RemoveGrain | rg | u8 | mode=17 | 1255.71 | 1256.72 | 1256.47 | 1256.300 | 0.429 |
| RemoveGrain | zsmooth | u8 | mode=20 | 5407.49 | 5425.1 | 5416.12 | 5416.237 | 7.190 |
| RemoveGrain | rg | u8 | mode=20 | 773.94 | 774.14 | 774.09 | 774.057 | 0.085 |
| RemoveGrain | std | u8 | mode=20 | 1992.59 | 1997.23 | 1996.39 | 1995.403 | 2.019 |
| RemoveGrain | zsmooth | u8 | mode=22 | 4991.01 | 5032.2 | 5015.8 | 5013.003 | 16.932 |
| RemoveGrain | rg | u8 | mode=22 | 1681.76 | 1683.92 | 1683.1 | 1682.927 | 0.890 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1802.64 | 1813.29 | 1812.32 | 1809.417 | 4.808 |
| RemoveGrain | rg | u16 | mode=1 | 1166.76 | 1166.94 | 1166.79 | 1166.830 | 0.079 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1715.61 | 1716.62 | 1716.05 | 1716.093 | 0.413 |
| RemoveGrain | rg | u16 | mode=4 | 820.75 | 836.08 | 831.68 | 829.503 | 6.445 |
| RemoveGrain | std | u16 | mode=4 | 1734.69 | 1744.76 | 1738.53 | 1739.327 | 4.149 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1721.49 | 1725.96 | 1723.9 | 1723.783 | 1.827 |
| RemoveGrain | rg | u16 | mode=12 | 1472.63 | 1481.69 | 1474.04 | 1476.120 | 3.980 |
| RemoveGrain | std | u16 | mode=12 | 1321.97 | 1322.69 | 1322.56 | 1322.407 | 0.313 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1784.63 | 1787.96 | 1785.16 | 1785.917 | 1.461 |
| RemoveGrain | rg | u16 | mode=17 | 1119.07 | 1119.52 | 1119.29 | 1119.293 | 0.184 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1675.34 | 1677.73 | 1675.92 | 1676.330 | 1.018 |
| RemoveGrain | rg | u16 | mode=20 | 695.18 | 695.58 | 695.35 | 695.370 | 0.164 |
| RemoveGrain | std | u16 | mode=20 | 1321.96 | 1323.31 | 1322.11 | 1322.460 | 0.604 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1769.38 | 1781.23 | 1772.13 | 1774.247 | 5.064 |
| RemoveGrain | rg | u16 | mode=22 | 1436.15 | 1443.68 | 1438.91 | 1439.580 | 3.110 |
| RemoveGrain | zsmooth | f32 | mode=1 | 799.32 | 805.2 | 802.34 | 802.287 | 2.401 |
| RemoveGrain | rg | f32 | mode=1 | 213 | 213.48 | 213.28 | 213.253 | 0.197 |
| RemoveGrain | zsmooth | f32 | mode=4 | 663.23 | 679.46 | 668.85 | 670.513 | 6.729 |
| RemoveGrain | rg | f32 | mode=4 | 64.92 | 64.93 | 64.93 | 64.927 | 0.005 |
| RemoveGrain | std | f32 | mode=4 | 718.78 | 720.84 | 720.62 | 720.080 | 0.924 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1145.29 | 1163.26 | 1149.9 | 1152.817 | 7.621 |
| RemoveGrain | rg | f32 | mode=12 | 340.93 | 341.08 | 340.98 | 340.997 | 0.062 |
| RemoveGrain | std | f32 | mode=12 | 1125 | 1130.03 | 1125.54 | 1126.857 | 2.255 |
| RemoveGrain | zsmooth | f32 | mode=17 | 889.01 | 903.64 | 901.98 | 898.210 | 6.541 |
| RemoveGrain | rg | f32 | mode=17 | 191.36 | 191.42 | 191.4 | 191.393 | 0.025 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1152.67 | 1158.34 | 1157.76 | 1156.257 | 2.547 |
| RemoveGrain | rg | f32 | mode=20 | 357.1 | 357.83 | 357.32 | 357.417 | 0.306 |
| RemoveGrain | std | f32 | mode=20 | 1119.87 | 1132.59 | 1125.78 | 1126.080 | 5.197 |
| RemoveGrain | zsmooth | f32 | mode=22 | 1109.19 | 1112.85 | 1109.34 | 1110.460 | 1.691 |
| RemoveGrain | rg | f32 | mode=22 | 158.49 | 158.61 | 158.5 | 158.533 | 0.054 |
| Repair | zsmooth | u8 | mode=1 | 1403.45 | 1415.22 | 1414.66 | 1411.110 | 5.421 |
| Repair | rg | u8 | mode=1 | 775.65 | 777.42 | 776.63 | 776.567 | 0.724 |
| Repair | zsmooth | u8 | mode=12 | 1255.76 | 1255.96 | 1255.95 | 1255.890 | 0.092 |
| Repair | rg | u8 | mode=12 | 586.73 | 587.11 | 586.84 | 586.893 | 0.160 |
| Repair | zsmooth | u8 | mode=13 | 1245.11 | 1255.61 | 1254.11 | 1251.610 | 4.637 |
| Repair | rg | u8 | mode=13 | 586.94 | 587.64 | 587.12 | 587.233 | 0.297 |
| Repair | zsmooth | u16 | mode=1 | 949.25 | 952.98 | 952.04 | 951.423 | 1.584 |
| Repair | rg | u16 | mode=1 | 729.08 | 729.54 | 729.36 | 729.327 | 0.189 |
| Repair | zsmooth | u16 | mode=12 | 910.47 | 911.4 | 911.3 | 911.057 | 0.417 |
| Repair | rg | u16 | mode=12 | 565.59 | 566.81 | 566.23 | 566.210 | 0.498 |
| Repair | zsmooth | u16 | mode=13 | 909.71 | 910 | 909.75 | 909.820 | 0.128 |
| Repair | rg | u16 | mode=13 | 543.61 | 544.56 | 544.18 | 544.117 | 0.390 |
| Repair | zsmooth | f32 | mode=1 | 498.81 | 507.64 | 505.33 | 503.927 | 3.739 |
| Repair | rg | f32 | mode=1 | 173.08 | 173.15 | 173.08 | 173.103 | 0.033 |
| Repair | zsmooth | f32 | mode=12 | 448.17 | 454.02 | 451.12 | 451.103 | 2.388 |
| Repair | rg | f32 | mode=12 | 61.03 | 61.18 | 61.1 | 61.103 | 0.061 |
| Repair | zsmooth | f32 | mode=13 | 446.11 | 447.63 | 447.04 | 446.927 | 0.626 |
| Repair | rg | f32 | mode=13 | 61.26 | 61.37 | 61.33 | 61.320 | 0.045 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6896.12 | 6909.97 | 6900.4 | 6902.163 | 5.790 |
| TemporalMedian | tmedian | u8 | radius=1 | 6223.96 | 6281.94 | 6248.03 | 6251.310 | 23.784 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2306.49 | 2346.85 | 2307.24 | 2320.193 | 18.852 |
| TemporalMedian | zsmooth | u8 | radius=10 | 929.46 | 933.11 | 932.76 | 931.777 | 1.644 |
| TemporalMedian | tmedian | u8 | radius=10 | 20.12 | 20.22 | 20.2 | 20.180 | 0.043 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.78 | 13.9 | 13.88 | 13.853 | 0.052 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1821.71 | 1825.26 | 1822.69 | 1823.220 | 1.497 |
| TemporalMedian | tmedian | u16 | radius=1 | 1694.82 | 1700.53 | 1697.11 | 1697.487 | 2.346 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 922.14 | 928.09 | 923.92 | 924.717 | 2.494 |
| TemporalMedian | zsmooth | u16 | radius=10 | 384.15 | 389.83 | 388.2 | 387.393 | 2.388 |
| TemporalMedian | tmedian | u16 | radius=10 | 17.03 | 17.76 | 17.44 | 17.410 | 0.299 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.72 | 13.82 | 13.78 | 13.773 | 0.041 |
| TemporalMedian | zsmooth | f32 | radius=1 | 873.73 | 881.22 | 877.74 | 877.563 | 3.060 |
| TemporalMedian | tmedian | f32 | radius=1 | 848.4 | 856.26 | 851.12 | 851.927 | 3.259 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 410.55 | 470.5 | 469.86 | 450.303 | 28.111 |
| TemporalMedian | zsmooth | f32 | radius=10 | 198.09 | 199.1 | 198.77 | 198.653 | 0.421 |
| TemporalMedian | tmedian | f32 | radius=10 | 18.03 | 18.3 | 18.03 | 18.120 | 0.127 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.28 | 14.64 | 14.64 | 14.520 | 0.170 |
| TemporalSoften | zsmooth | u8 | radius=1 | 4966.42 | 4985.53 | 4975.6 | 4975.850 | 7.804 |
| TemporalSoften | focus2 | u8 | radius=1 | 1623.38 | 1716.87 | 1716.05 | 1685.433 | 43.880 |
| TemporalSoften | std | u8 | radius=1 | 1680.75 | 1685.44 | 1681.76 | 1682.650 | 2.015 |
| TemporalSoften | zsmooth | u8 | radius=7 | 1231.15 | 1243.48 | 1234.68 | 1236.437 | 5.185 |
| TemporalSoften | focus2 | u8 | radius=7 | 434.13 | 436.29 | 435.99 | 435.470 | 0.955 |
| TemporalSoften | std | u8 | radius=7 | 526.64 | 529.87 | 527.33 | 527.947 | 1.389 |
| TemporalSoften | zsmooth | u16 | radius=1 | 1554.1 | 1557.68 | 1555.32 | 1555.700 | 1.486 |
| TemporalSoften | focus2 | u16 | radius=1 | 333.27 | 333.9 | 333.67 | 333.613 | 0.260 |
| TemporalSoften | std | u16 | radius=1 | 832.09 | 837.23 | 836.02 | 835.113 | 2.194 |
| TemporalSoften | zsmooth | u16 | radius=7 | 512.84 | 514.46 | 513.15 | 513.483 | 0.702 |
| TemporalSoften | focus2 | u16 | radius=7 | 123.9 | 124.87 | 124.75 | 124.507 | 0.432 |
| TemporalSoften | std | u16 | radius=7 | 317.13 | 317.78 | 317.49 | 317.467 | 0.266 |
| TemporalSoften | zsmooth | f32 | radius=1 | 934.64 | 937.83 | 937.21 | 936.560 | 1.381 |
| TemporalSoften | std | f32 | radius=1 | 605.92 | 608.64 | 606.17 | 606.910 | 1.228 |
| TemporalSoften | zsmooth | f32 | radius=7 | 273.15 | 275.79 | 274.37 | 274.437 | 1.079 |
| TemporalSoften | std | f32 | radius=7 | 207.33 | 213.5 | 212.84 | 211.223 | 2.766 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 472.88 | 475.93 | 474.62 | 474.477 | 1.249 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 160.04 | 161.6 | 161.16 | 160.933 | 0.657 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1408.91 | 1428.16 | 1410.66 | 1415.910 | 8.691 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 193.98 | 195.17 | 195.09 | 194.747 | 0.543 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 451.64 | 452.48 | 451.93 | 452.017 | 0.348 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 150.42 | 151.97 | 150.76 | 151.050 | 0.665 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 1429.71 | 1435.38 | 1432.72 | 1432.603 | 2.316 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 181.15 | 181.93 | 181.72 | 181.600 | 0.330 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 397.06 | 397.44 | 397.2 | 397.233 | 0.157 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 146.92 | 147.47 | 147.33 | 147.240 | 0.233 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 933.34 | 942.17 | 935.37 | 936.960 | 3.776 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 168.7 | 169.11 | 169.05 | 168.953 | 0.181 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 11004.75 | 11099.67 | 11014.26 | 11039.560 | 42.681 |
| VerticalCleaner | rg | u8 | mode=1 | 9059.59 | 9328.8 | 9316.02 | 9234.803 | 124.004 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 8832.76 | 9114.38 | 9067.11 | 9004.750 | 123.137 |
| VerticalCleaner | rg | u8 | mode=2 | 178.87 | 178.89 | 178.89 | 178.883 | 0.009 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 1992.82 | 2029.11 | 2010.54 | 2010.823 | 14.817 |
| VerticalCleaner | rg | u16 | mode=1 | 1723.55 | 1728.68 | 1725.31 | 1725.847 | 2.128 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1964.6 | 1970.51 | 1966.72 | 1967.277 | 2.445 |
| VerticalCleaner | rg | u16 | mode=2 | 182.85 | 182.88 | 182.86 | 182.863 | 0.012 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1333.26 | 1344.21 | 1341.13 | 1339.533 | 4.611 |
| VerticalCleaner | rg | f32 | mode=1 | 1261.89 | 1266.98 | 1266.4 | 1265.090 | 2.275 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 744.37 | 753.92 | 747.96 | 748.750 | 3.939 |
| VerticalCleaner | rg | f32 | mode=2 | 92.22 | 92.22 | 92.22 | 92.220 | 0.000 |

## 0.9 - Zig 0.14.0 - AVX2
Source: BlankClip YUV420, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

CPU tuning: AVX2 (not znver4 / znver5)

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6682.59 | 6889.66 | 6881.06 | 6817.770 | 95.651 |
| Clense | rg | u8 | function=Clense | 6330.54 | 6348.04 | 6347.23 | 6341.937 | 8.065 |
| Clense | zsmooth | u8 | function=ForwardClense | 6846.16 | 6868.5 | 6864.26 | 6859.640 | 9.688 |
| Clense | rg | u8 | function=ForwardClense | 871.49 | 872.22 | 871.93 | 871.880 | 0.300 |
| Clense | zsmooth | u8 | function=BackwardClense | 6841.71 | 6858.44 | 6847.61 | 6849.253 | 6.928 |
| Clense | rg | u8 | function=BackwardClense | 873.18 | 873.54 | 873.3 | 873.340 | 0.150 |
| Clense | zsmooth | u16 | function=Clense | 1845.99 | 1854.52 | 1848.66 | 1849.723 | 3.563 |
| Clense | rg | u16 | function=Clense | 1465.01 | 1468.5 | 1465.15 | 1466.220 | 1.613 |
| Clense | zsmooth | u16 | function=ForwardClense | 1805.58 | 1814.63 | 1809.06 | 1809.757 | 3.727 |
| Clense | rg | u16 | function=ForwardClense | 546.46 | 546.8 | 546.53 | 546.597 | 0.147 |
| Clense | zsmooth | u16 | function=BackwardClense | 1810.71 | 1816.19 | 1812.17 | 1813.023 | 2.317 |
| Clense | rg | u16 | function=BackwardClense | 547.35 | 547.9 | 547.45 | 547.567 | 0.239 |
| Clense | zsmooth | f32 | function=Clense | 861.4 | 864.61 | 863.69 | 863.233 | 1.350 |
| Clense | rg | f32 | function=Clense | 808.46 | 813.11 | 811.56 | 811.043 | 1.933 |
| Clense | zsmooth | f32 | function=ForwardClense | 855 | 857.66 | 855.53 | 856.063 | 1.150 |
| Clense | rg | f32 | function=ForwardClense | 250.59 | 252.54 | 252.19 | 251.773 | 0.849 |
| Clense | zsmooth | f32 | function=BackwardClense | 852.51 | 853.31 | 852.89 | 852.903 | 0.327 |
| Clense | rg | f32 | function=BackwardClense | 251.15 | 252.47 | 251.4 | 251.673 | 0.572 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1480.08 | 1485.07 | 1483.78 | 1482.977 | 2.115 |
| DegrainMedian | dgm | u8 | mode=0 | 178.76 | 178.81 | 178.79 | 178.787 | 0.021 |
| DegrainMedian | zsmooth | u8 | mode=1 | 405.69 | 406.13 | 405.74 | 405.853 | 0.197 |
| DegrainMedian | dgm | u8 | mode=1 | 458.77 | 459.23 | 458.85 | 458.950 | 0.201 |
| DegrainMedian | zsmooth | u8 | mode=2 | 403.85 | 406.32 | 405.64 | 405.270 | 1.042 |
| DegrainMedian | dgm | u8 | mode=2 | 490.61 | 491.26 | 491.11 | 490.993 | 0.278 |
| DegrainMedian | zsmooth | u8 | mode=3 | 431.03 | 431.43 | 431.24 | 431.233 | 0.163 |
| DegrainMedian | dgm | u8 | mode=3 | 516.25 | 518.15 | 516.59 | 516.997 | 0.827 |
| DegrainMedian | zsmooth | u8 | mode=4 | 403.34 | 406 | 404.46 | 404.600 | 1.090 |
| DegrainMedian | dgm | u8 | mode=4 | 482.43 | 483.27 | 483.11 | 482.937 | 0.364 |
| DegrainMedian | zsmooth | u8 | mode=5 | 296.02 | 296.38 | 296.06 | 296.153 | 0.161 |
| DegrainMedian | dgm | u8 | mode=5 | 573.26 | 573.34 | 573.3 | 573.300 | 0.033 |
| DegrainMedian | zsmooth | u16 | mode=0 | 601.53 | 605.99 | 601.81 | 603.110 | 2.040 |
| DegrainMedian | dgm | u16 | mode=0 | 85.22 | 85.23 | 85.23 | 85.227 | 0.005 |
| DegrainMedian | zsmooth | u16 | mode=1 | 174.15 | 174.47 | 174.28 | 174.300 | 0.131 |
| DegrainMedian | dgm | u16 | mode=1 | 95.95 | 96.05 | 96.01 | 96.003 | 0.041 |
| DegrainMedian | zsmooth | u16 | mode=2 | 174.01 | 175.02 | 174.57 | 174.533 | 0.413 |
| DegrainMedian | dgm | u16 | mode=2 | 110.16 | 110.27 | 110.19 | 110.207 | 0.046 |
| DegrainMedian | zsmooth | u16 | mode=3 | 183.86 | 184.05 | 183.98 | 183.963 | 0.078 |
| DegrainMedian | dgm | u16 | mode=3 | 126.38 | 126.64 | 126.6 | 126.540 | 0.114 |
| DegrainMedian | zsmooth | u16 | mode=4 | 174.02 | 174.37 | 174.27 | 174.220 | 0.147 |
| DegrainMedian | dgm | u16 | mode=4 | 106.06 | 106.13 | 106.11 | 106.100 | 0.029 |
| DegrainMedian | zsmooth | u16 | mode=5 | 137.64 | 137.75 | 137.71 | 137.700 | 0.045 |
| DegrainMedian | dgm | u16 | mode=5 | 162.42 | 162.98 | 162.95 | 162.783 | 0.257 |
| DegrainMedian | zsmooth | f32 | mode=0 | 241.75 | 243.1 | 242.8 | 242.550 | 0.579 |
| DegrainMedian | zsmooth | f32 | mode=1 | 83.84 | 83.87 | 83.84 | 83.850 | 0.014 |
| DegrainMedian | zsmooth | f32 | mode=2 | 91.47 | 91.51 | 91.5 | 91.493 | 0.017 |
| DegrainMedian | zsmooth | f32 | mode=3 | 94.12 | 94.35 | 94.17 | 94.213 | 0.099 |
| DegrainMedian | zsmooth | f32 | mode=4 | 90.11 | 90.22 | 90.17 | 90.167 | 0.045 |
| DegrainMedian | zsmooth | f32 | mode=5 | 115.89 | 116.23 | 116.18 | 116.100 | 0.150 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1796.32 | 1799.11 | 1796.53 | 1797.320 | 1.269 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1531.84 | 1534.06 | 1533.01 | 1532.970 | 0.907 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 897.57 | 898.01 | 897.83 | 897.803 | 0.181 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 409.01 | 409.07 | 409.03 | 409.037 | 0.025 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 1123.78 | 1124.6 | 1124.5 | 1124.293 | 0.365 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.33 | 589.58 | 589.4 | 589.437 | 0.105 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 460.56 | 460.74 | 460.57 | 460.623 | 0.083 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 401.88 | 402.04 | 401.89 | 401.937 | 0.073 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 821.35 | 827.66 | 826.88 | 825.297 | 2.809 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 398.5 | 400.41 | 400.04 | 399.650 | 0.827 |
| InterQuartileMean | zsmooth | u8 |  | 1453.7 | 1454.66 | 1454.21 | 1454.190 | 0.392 |
| InterQuartileMean | zsmooth | u16 |  | 666.37 | 666.7 | 666.47 | 666.513 | 0.138 |
| InterQuartileMean | zsmooth | f32 |  | 314.66 | 314.83 | 314.71 | 314.733 | 0.071 |
| RemoveGrain | zsmooth | u8 | mode=1 | 5131.96 | 5283.14 | 5248.59 | 5221.230 | 64.680 |
| RemoveGrain | rg | u8 | mode=1 | 1400.54 | 1404.85 | 1401.02 | 1402.137 | 1.929 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3681.66 | 3745.1 | 3724.32 | 3717.027 | 26.408 |
| RemoveGrain | rg | u8 | mode=4 | 906.55 | 924.96 | 906.78 | 912.763 | 8.625 |
| RemoveGrain | std | u8 | mode=4 | 5599.54 | 5743.15 | 5600.74 | 5647.810 | 67.417 |
| RemoveGrain | zsmooth | u8 | mode=12 | 3496.78 | 3557.59 | 3513.48 | 3522.617 | 25.652 |
| RemoveGrain | rg | u8 | mode=12 | 2378.79 | 2391.19 | 2389.07 | 2386.350 | 5.415 |
| RemoveGrain | std | u8 | mode=12 | 1988.57 | 1993.63 | 1991.27 | 1991.157 | 2.067 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4737.74 | 4863.36 | 4840.64 | 4813.913 | 54.655 |
| RemoveGrain | rg | u8 | mode=17 | 1255.99 | 1256.51 | 1256.47 | 1256.323 | 0.236 |
| RemoveGrain | zsmooth | u8 | mode=20 | 3517.9 | 3539.62 | 3521.13 | 3526.217 | 9.569 |
| RemoveGrain | rg | u8 | mode=20 | 773.75 | 773.86 | 773.83 | 773.813 | 0.046 |
| RemoveGrain | std | u8 | mode=20 | 1986.68 | 1996.87 | 1987.39 | 1990.313 | 4.645 |
| RemoveGrain | zsmooth | u8 | mode=22 | 3753.68 | 3805.05 | 3788.92 | 3782.550 | 21.450 |
| RemoveGrain | rg | u8 | mode=22 | 1682.11 | 1692.35 | 1683.79 | 1686.083 | 4.484 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1730.15 | 1749.6 | 1747.37 | 1742.373 | 8.691 |
| RemoveGrain | rg | u16 | mode=1 | 1165.94 | 1166.35 | 1165.98 | 1166.090 | 0.185 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1584.27 | 1607.78 | 1605.95 | 1599.333 | 10.678 |
| RemoveGrain | rg | u16 | mode=4 | 825.35 | 841.3 | 830.31 | 832.320 | 6.665 |
| RemoveGrain | std | u16 | mode=4 | 1727.35 | 1739.2 | 1734.37 | 1733.640 | 4.865 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1325.24 | 1328 | 1326.99 | 1326.743 | 1.140 |
| RemoveGrain | rg | u16 | mode=12 | 1471.35 | 1481.21 | 1479.32 | 1477.293 | 4.273 |
| RemoveGrain | std | u16 | mode=12 | 1319.4 | 1322.53 | 1322.19 | 1321.373 | 1.402 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1733.2 | 1740.43 | 1734.57 | 1736.067 | 3.136 |
| RemoveGrain | rg | u16 | mode=17 | 1115.36 | 1118.21 | 1118.07 | 1117.213 | 1.312 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1200.34 | 1204.2 | 1203.79 | 1202.777 | 1.731 |
| RemoveGrain | rg | u16 | mode=20 | 694.65 | 695.72 | 695 | 695.123 | 0.445 |
| RemoveGrain | std | u16 | mode=20 | 1321 | 1322.6 | 1321.54 | 1321.713 | 0.665 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1484.62 | 1487.17 | 1485.51 | 1485.767 | 1.057 |
| RemoveGrain | rg | u16 | mode=22 | 1435.62 | 1443.5 | 1439.04 | 1439.387 | 3.226 |
| RemoveGrain | zsmooth | f32 | mode=1 | 617.58 | 618.93 | 618.68 | 618.397 | 0.586 |
| RemoveGrain | rg | f32 | mode=1 | 213.14 | 213.31 | 213.17 | 213.207 | 0.074 |
| RemoveGrain | zsmooth | f32 | mode=4 | 465.83 | 466.14 | 465.93 | 465.967 | 0.129 |
| RemoveGrain | rg | f32 | mode=4 | 64.83 | 65 | 64.96 | 64.930 | 0.073 |
| RemoveGrain | std | f32 | mode=4 | 719.41 | 722.92 | 720.28 | 720.870 | 1.492 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1100.87 | 1108.09 | 1106.7 | 1105.220 | 3.128 |
| RemoveGrain | rg | f32 | mode=12 | 340.76 | 341.24 | 340.8 | 340.933 | 0.217 |
| RemoveGrain | std | f32 | mode=12 | 1119.16 | 1128.73 | 1125.77 | 1124.553 | 4.001 |
| RemoveGrain | zsmooth | f32 | mode=17 | 672.84 | 675.37 | 672.85 | 673.687 | 1.190 |
| RemoveGrain | rg | f32 | mode=17 | 191.19 | 191.49 | 191.4 | 191.360 | 0.126 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1110.46 | 1112.62 | 1111.68 | 1111.587 | 0.884 |
| RemoveGrain | rg | f32 | mode=20 | 357.28 | 358.16 | 357.61 | 357.683 | 0.363 |
| RemoveGrain | std | f32 | mode=20 | 1121.18 | 1125.16 | 1124.32 | 1123.553 | 1.713 |
| RemoveGrain | zsmooth | f32 | mode=22 | 900.25 | 905.13 | 901 | 902.127 | 2.146 |
| RemoveGrain | rg | f32 | mode=22 | 158.42 | 158.6 | 158.57 | 158.530 | 0.079 |
| Repair | zsmooth | u8 | mode=1 | 1472.63 | 1475.56 | 1474.89 | 1474.360 | 1.254 |
| Repair | rg | u8 | mode=1 | 775.15 | 776.06 | 775.17 | 775.460 | 0.424 |
| Repair | zsmooth | u8 | mode=12 | 1308.44 | 1310.7 | 1309.57 | 1309.570 | 0.923 |
| Repair | rg | u8 | mode=12 | 586.08 | 588.98 | 588.51 | 587.857 | 1.271 |
| Repair | zsmooth | u8 | mode=13 | 1305.96 | 1309.74 | 1306.87 | 1307.523 | 1.611 |
| Repair | rg | u8 | mode=13 | 586.37 | 593.25 | 589.96 | 589.860 | 2.810 |
| Repair | zsmooth | u16 | mode=1 | 920.41 | 924.08 | 923.18 | 922.557 | 1.562 |
| Repair | rg | u16 | mode=1 | 729.3 | 730.12 | 729.68 | 729.700 | 0.335 |
| Repair | zsmooth | u16 | mode=12 | 861.38 | 870.61 | 867.76 | 866.583 | 3.859 |
| Repair | rg | u16 | mode=12 | 564.74 | 567.43 | 564.92 | 565.697 | 1.228 |
| Repair | zsmooth | u16 | mode=13 | 860.52 | 866.31 | 865.09 | 863.973 | 2.492 |
| Repair | rg | u16 | mode=13 | 544.17 | 544.34 | 544.21 | 544.240 | 0.073 |
| Repair | zsmooth | f32 | mode=1 | 418.7 | 420.88 | 419.99 | 419.857 | 0.895 |
| Repair | rg | f32 | mode=1 | 173.08 | 173.18 | 173.16 | 173.140 | 0.043 |
| Repair | zsmooth | f32 | mode=12 | 336.54 | 337.13 | 336.93 | 336.867 | 0.245 |
| Repair | rg | f32 | mode=12 | 60.94 | 61.04 | 60.95 | 60.977 | 0.045 |
| Repair | zsmooth | f32 | mode=13 | 336.13 | 336.79 | 336.26 | 336.393 | 0.285 |
| Repair | rg | f32 | mode=13 | 61.34 | 61.37 | 61.36 | 61.357 | 0.012 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6910.77 | 6943.68 | 6933.44 | 6929.297 | 13.751 |
| TemporalMedian | tmedian | u8 | radius=1 | 6123.75 | 6208.86 | 6178.14 | 6170.250 | 35.191 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2314.94 | 2339.12 | 2329.65 | 2327.903 | 9.948 |
| TemporalMedian | zsmooth | u8 | radius=10 | 966.99 | 977.06 | 976.83 | 973.627 | 4.694 |
| TemporalMedian | tmedian | u8 | radius=10 | 20.09 | 20.17 | 20.13 | 20.130 | 0.033 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.82 | 13.91 | 13.9 | 13.877 | 0.040 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1796.5 | 1808.96 | 1806.56 | 1804.007 | 5.398 |
| TemporalMedian | tmedian | u16 | radius=1 | 1694.6 | 1701.66 | 1698.14 | 1698.133 | 2.882 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 924.83 | 925.34 | 924.97 | 925.047 | 0.215 |
| TemporalMedian | zsmooth | u16 | radius=10 | 384.93 | 386.77 | 386.42 | 386.040 | 0.798 |
| TemporalMedian | tmedian | u16 | radius=10 | 17.09 | 17.59 | 17.15 | 17.277 | 0.223 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.74 | 13.79 | 13.75 | 13.760 | 0.022 |
| TemporalMedian | zsmooth | f32 | radius=1 | 866.65 | 869.59 | 868 | 868.080 | 1.202 |
| TemporalMedian | tmedian | f32 | radius=1 | 851.41 | 859.72 | 855.13 | 855.420 | 3.399 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 466.53 | 471.21 | 469.93 | 469.223 | 1.975 |
| TemporalMedian | zsmooth | f32 | radius=10 | 194.16 | 194.74 | 194.3 | 194.400 | 0.247 |
| TemporalMedian | tmedian | f32 | radius=10 | 17.81 | 18.02 | 17.88 | 17.903 | 0.087 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.58 | 14.63 | 14.61 | 14.607 | 0.021 |
| TemporalSoften | zsmooth | u8 | radius=1 | 3074.02 | 3078.95 | 3075.25 | 3076.073 | 2.095 |
| TemporalSoften | focus2 | u8 | radius=1 | 1625.86 | 1716.43 | 1715.46 | 1685.917 | 42.468 |
| TemporalSoften | std | u8 | radius=1 | 1681.6 | 1684.52 | 1683.73 | 1683.283 | 1.233 |
| TemporalSoften | zsmooth | u8 | radius=7 | 808.96 | 817.31 | 817.23 | 814.500 | 3.918 |
| TemporalSoften | focus2 | u8 | radius=7 | 434.47 | 436.65 | 436.44 | 435.853 | 0.982 |
| TemporalSoften | std | u8 | radius=7 | 530.63 | 530.77 | 530.72 | 530.707 | 0.058 |
| TemporalSoften | zsmooth | u16 | radius=1 | 953.66 | 954.7 | 954.4 | 954.253 | 0.437 |
| TemporalSoften | focus2 | u16 | radius=1 | 331.52 | 333.67 | 333.62 | 332.937 | 1.002 |
| TemporalSoften | std | u16 | radius=1 | 833.83 | 854.37 | 836.44 | 841.547 | 9.130 |
| TemporalSoften | zsmooth | u16 | radius=7 | 327.55 | 328.57 | 327.73 | 327.950 | 0.445 |
| TemporalSoften | focus2 | u16 | radius=7 | 123.81 | 124.32 | 124.31 | 124.147 | 0.238 |
| TemporalSoften | std | u16 | radius=7 | 317.76 | 318.72 | 317.89 | 318.123 | 0.425 |
| TemporalSoften | zsmooth | f32 | radius=1 | 908.61 | 910.64 | 910.26 | 909.837 | 0.881 |
| TemporalSoften | std | f32 | radius=1 | 613.09 | 637.95 | 632.92 | 627.987 | 10.732 |
| TemporalSoften | zsmooth | f32 | radius=7 | 230.77 | 233.71 | 233 | 232.493 | 1.253 |
| TemporalSoften | std | f32 | radius=7 | 208.23 | 212.12 | 210.11 | 210.153 | 1.588 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 335.86 | 336.19 | 335.87 | 335.973 | 0.153 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 158.05 | 162.36 | 161.32 | 160.577 | 1.836 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1094.92 | 1097.67 | 1096.28 | 1096.290 | 1.123 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 194.06 | 194.92 | 194.54 | 194.507 | 0.352 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 313.81 | 314.58 | 313.97 | 314.120 | 0.332 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 150.7 | 151.9 | 151.59 | 151.397 | 0.509 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 689.34 | 691.59 | 691.19 | 690.707 | 0.980 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 181.16 | 181.79 | 181.36 | 181.437 | 0.263 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 207.02 | 207.98 | 207.43 | 207.477 | 0.393 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 146.58 | 147.29 | 146.77 | 146.880 | 0.300 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 644.91 | 646.37 | 646.1 | 645.793 | 0.634 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 168.74 | 169.77 | 169 | 169.170 | 0.437 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 10622.74 | 10643.4 | 10630.44 | 10632.193 | 8.525 |
| VerticalCleaner | rg | u8 | mode=1 | 9125.39 | 9370.07 | 9305.22 | 9266.893 | 103.501 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 6951.7 | 6976.95 | 6963.31 | 6963.987 | 10.319 |
| VerticalCleaner | rg | u8 | mode=2 | 178.9 | 179 | 178.91 | 178.937 | 0.045 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2007.15 | 2040.11 | 2038.76 | 2028.673 | 15.229 |
| VerticalCleaner | rg | u16 | mode=1 | 1723.3 | 1725.93 | 1723.52 | 1724.250 | 1.191 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1877.34 | 1880.48 | 1878.64 | 1878.820 | 1.288 |
| VerticalCleaner | rg | u16 | mode=2 | 182.82 | 182.89 | 182.89 | 182.867 | 0.033 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1291.34 | 1302.53 | 1295.72 | 1296.530 | 4.604 |
| VerticalCleaner | rg | f32 | mode=1 | 1263.45 | 1269.06 | 1266.2 | 1266.237 | 2.290 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 447.73 | 448.64 | 447.99 | 448.120 | 0.383 |
| VerticalCleaner | rg | f32 | mode=2 | 92.22 | 92.26 | 92.25 | 92.243 | 0.017 |

## 0.9 - Zig 0.12.1 - AVX2
Source: BlankClip YUV420, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

CPU tuning: AVX2 (not znver4 / znver5)

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| TemporalMedian | zsmooth | u8 | radius=1 | 6681.7 | 6835.19 | 6806.09 | 6774.326666666667 | 66.56564195505732 |
| TemporalMedian | tmedian | u8 | radius=1 | 6266.91 | 6275.24 | 6272.27 | 6271.473333333332 | 3.447050268788618 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2301.82 | 2313.06 | 2303.61 | 2306.1633333333334 | 4.931127885405252 |
| TemporalMedian | zsmooth | u8 | radius=10 | 939.68 | 950.82 | 948.69 | 946.3966666666666 | 4.8283491542716765 |
| TemporalMedian | tmedian | u8 | radius=10 | 20.94 | 21.03 | 20.98 | 20.983333333333334 | 0.036817870057290834 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.59 | 13.85 | 13.83 | 13.756666666666668 | 0.11813363431112898 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1832.13 | 1833.54 | 1833.51 | 1833.0600000000002 | 0.6577233460961516 |
| TemporalMedian | tmedian | u16 | radius=1 | 1710.19 | 1717.08 | 1711.55 | 1712.9399999999998 | 2.9796084753984724 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 930.03 | 935.84 | 933.76 | 933.21 | 2.403594530420382 |
| TemporalMedian | zsmooth | u16 | radius=10 | 378.6 | 386.95 | 378.99 | 381.5133333333333 | 3.84759954026171 |
| TemporalMedian | tmedian | u16 | radius=10 | 19.8 | 20.27 | 19.85 | 19.973333333333333 | 0.2107657994604958 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.87 | 13.88 | 13.88 | 13.876666666666667 | 0.004714045207911053 |
| TemporalMedian | zsmooth | f32 | radius=1 | 915.74 | 922.27 | 917.61 | 918.54 | 2.7457725081780895 |
| TemporalMedian | tmedian | f32 | radius=1 | 886.44 | 892.59 | 887.48 | 888.8366666666667 | 2.6877541223523775 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 463.98 | 466.86 | 464.91 | 465.25 | 1.2000833304400131 |
| TemporalMedian | zsmooth | f32 | radius=10 | 189.38 | 192.09 | 190.47 | 190.64666666666668 | 1.1133832324147106 |
| TemporalMedian | tmedian | f32 | radius=10 | 16.64 | 17.53 | 17.14 | 17.103333333333335 | 0.3642648609032843 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.57 | 14.61 | 14.59 | 14.589999999999998 | 0.016329931618554172 |
| TemporalSoften | zsmooth | u8 | radius=1 | 3072.13 | 3080.48 | 3075.02 | 3075.8766666666666 | 3.4622760657630045 |
| TemporalSoften | focus2 | u8 | radius=1 | 1769.09 | 1824.46 | 1777.47 | 1790.3400000000001 | 24.36783262144314 |
| TemporalSoften | zsmooth | u8 | radius=7 | 803.72 | 813.38 | 812.74 | 809.9466666666667 | 4.4106638452227855 |
| TemporalSoften | focus2 | u8 | radius=7 | 414.03 | 414.86 | 414.08 | 414.32333333333327 | 0.3800292386412327 |
| TemporalSoften | zsmooth | u16 | radius=1 | 952.72 | 953.19 | 953.09 | 953 | 0.20215505600075995 |
| TemporalSoften | focus2 | u16 | radius=1 | 335.44 | 337.4 | 336.84 | 336.56 | 0.8242976808572562 |
| TemporalSoften | zsmooth | u16 | radius=7 | 327.01 | 327.46 | 327.15 | 327.20666666666665 | 0.18803073034893564 |
| TemporalSoften | focus2 | u16 | radius=7 | 124.61 | 125.03 | 124.89 | 124.84333333333332 | 0.17461067804945132 |
| TemporalSoften | zsmooth | f32 | radius=1 | 893.19 | 894.44 | 894.03 | 893.8866666666667 | 0.5202777036245942 |
| TemporalSoften | zsmooth | f32 | radius=7 | 232.99 | 236.05 | 234.8 | 234.61333333333334 | 1.2561935448895702 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1793.15 | 1796.42 | 1794.66 | 1794.7433333333336 | 1.3362717621136062 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1574.47 | 1575.34 | 1575.23 | 1575.0133333333333 | 0.3868103181433985 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 898.27 | 898.6 | 898.45 | 898.44 | 0.13490737563233818 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 412.45 | 412.77 | 412.68 | 412.6333333333334 | 0.13474255287605136 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 1145.39 | 1147.26 | 1146.5 | 1146.3833333333334 | 0.767868623022292 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 609.87 | 610.18 | 609.98 | 610.0099999999999 | 0.12832251036610923 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 462.96 | 463.02 | 463.01 | 462.99666666666667 | 0.0262466929133753 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 695.38 | 716.07 | 715.55 | 709 | 9.633133792627753 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 889.94 | 892.91 | 892.65 | 891.8333333333334 | 1.3429900305743592 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 413.27 | 414.56 | 413.42 | 413.75 | 0.5760208329565898 |
| Clense | zsmooth | u8 | function=Clense | 6814.75 | 6845.75 | 6826.57 | 6829.0233333333335 | 12.774039646442677 |
| Clense | rg | u8 | function=Clense | 491.53 | 491.54 | 491.54 | 491.53666666666663 | 0.0047140452079328255 |
| Clense | zsmooth | u8 | function=ForwardClense | 6796.24 | 6812.7 | 6796.69 | 6801.876666666667 | 7.655457022426755 |
| Clense | rg | u8 | function=ForwardClense | 361.34 | 361.61 | 361.58 | 361.51 | 0.12083045973595814 |
| Clense | zsmooth | u8 | function=BackwardClense | 6794.56 | 6813.86 | 6802.83 | 6803.75 | 7.906001939454736 |
| Clense | rg | u8 | function=BackwardClense | 361.4 | 361.66 | 361.57 | 361.54333333333335 | 0.10780641085866007 |
| Clense | zsmooth | u16 | function=Clense | 1883.06 | 1891.96 | 1889.23 | 1888.0833333333333 | 3.7227797260768978 |
| Clense | rg | u16 | function=Clense | 453.92 | 454.9 | 454.45 | 454.42333333333335 | 0.40052743004969016 |
| Clense | zsmooth | u16 | function=ForwardClense | 1845.41 | 1847.82 | 1847.02 | 1846.75 | 1.0022308449985686 |
| Clense | rg | u16 | function=ForwardClense | 358.18 | 358.35 | 358.31 | 358.28000000000003 | 0.0725718035235953 |
| Clense | zsmooth | u16 | function=BackwardClense | 1847.15 | 1851.52 | 1847.76 | 1848.8100000000002 | 1.9323733248693273 |
| Clense | rg | u16 | function=BackwardClense | 358.11 | 358.6 | 358.4 | 358.37000000000006 | 0.20116328359486316 |
| Clense | zsmooth | f32 | function=Clense | 926.53 | 929.39 | 928.56 | 928.16 | 1.2013603400589978 |
| Clense | rg | f32 | function=Clense | 868.21 | 874.54 | 869.92 | 870.89 | 2.6736865934510488 |
| Clense | zsmooth | f32 | function=ForwardClense | 913.48 | 917.57 | 915.3 | 915.4499999999999 | 1.6731009134737564 |
| Clense | rg | f32 | function=ForwardClense | 255.17 | 256.67 | 255.91 | 255.91666666666666 | 0.6123905797954736 |
| Clense | zsmooth | f32 | function=BackwardClense | 912.89 | 918.46 | 913.61 | 914.9866666666667 | 2.4735444653820786 |
| Clense | rg | f32 | function=BackwardClense | 256.12 | 256.87 | 256.78 | 256.59 | 0.33436506994600373 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 10863.23 | 10931.33 | 10876.11 | 10890.223333333333 | 29.538586440263003 |
| VerticalCleaner | rg | u8 | mode=1 | 7897.58 | 8045.5 | 8011.71 | 7984.93 | 63.28748112120336 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 6973.1 | 7007.32 | 7001.43 | 6993.95 | 14.937980675669 |
| VerticalCleaner | rg | u8 | mode=2 | 177.6 | 177.68 | 177.65 | 177.64333333333335 | 0.03299831645537762 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2009.88 | 2030.92 | 2013.33 | 2018.0433333333333 | 9.21346960825413 |
| VerticalCleaner | rg | u16 | mode=1 | 1714.89 | 1717.42 | 1716.63 | 1716.3133333333335 | 1.0568611808348045 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1882.56 | 1885.26 | 1885.2 | 1884.3400000000001 | 1.258888398548531 |
| VerticalCleaner | rg | u16 | mode=2 | 181.06 | 181.35 | 181.28 | 181.23000000000002 | 0.1235583532856682 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1340.39 | 1343.75 | 1342.16 | 1342.1000000000001 | 1.3723702124426518 |
| VerticalCleaner | rg | f32 | mode=1 | 1275.37 | 1279.28 | 1275.4 | 1276.6833333333334 | 1.8361614550166494 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 449.61 | 450.17 | 449.78 | 449.8533333333333 | 0.23442601296690185 |
| VerticalCleaner | rg | f32 | mode=2 | 92.16 | 92.24 | 92.24 | 92.21333333333332 | 0.03771236166328173 |
| RemoveGrain | zsmooth | u8 | mode=1 | 5099.18 | 5182.34 | 5181.25 | 5154.256666666667 | 38.94762665711755 |
| RemoveGrain | rg | u8 | mode=1 | 1348.74 | 1350.06 | 1349.4 | 1349.4 | 0.5388877434122732 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3655.95 | 3671.62 | 3662.35 | 3663.306666666666 | 6.432917084979611 |
| RemoveGrain | rg | u8 | mode=4 | 924.36 | 924.93 | 924.64 | 924.6433333333333 | 0.2327134623427348 |
| RemoveGrain | std | u8 | mode=4 | 5597.81 | 5720.57 | 5633.75 | 5650.71 | 51.53145059087676 |
| RemoveGrain | zsmooth | u8 | mode=12 | 3514.25 | 3570.28 | 3515.93 | 3533.486666666667 | 26.025854239369277 |
| RemoveGrain | rg | u8 | mode=12 | 2517.64 | 2529.38 | 2520.6 | 2522.54 | 4.985285013584249 |
| RemoveGrain | std | u8 | mode=12 | 2058.19 | 2066.84 | 2066.24 | 2063.7566666666667 | 3.9438418945095433 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4723.7 | 4730.89 | 4730.28 | 4728.29 | 3.255160006308054 |
| RemoveGrain | rg | u8 | mode=17 | 1302.58 | 1304.07 | 1303.95 | 1303.533333333333 | 0.6758862494697302 |
| RemoveGrain | zsmooth | u8 | mode=20 | 3501.01 | 3515.2 | 3513.66 | 3509.9566666666665 | 6.3574121219948125 |
| RemoveGrain | rg | u8 | mode=20 | 763.07 | 764.07 | 764.04 | 763.7266666666668 | 0.464494946749195 |
| RemoveGrain | std | u8 | mode=20 | 2064.04 | 2066.24 | 2065.23 | 2065.17 | 0.8991477446262872 |
| RemoveGrain | zsmooth | u8 | mode=22 | 3815.88 | 3871.88 | 3864.57 | 3850.776666666667 | 24.855476034244234 |
| RemoveGrain | rg | u8 | mode=22 | 1743.36 | 1747.68 | 1745.3 | 1745.4466666666667 | 1.7666792452383069 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1742.53 | 1747.51 | 1745.57 | 1745.2033333333331 | 2.049541954247885 |
| RemoveGrain | rg | u16 | mode=1 | 1160.46 | 1162.3 | 1160.74 | 1161.1666666666667 | 0.8094991592885287 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1586.8 | 1605.28 | 1589.74 | 1593.9399999999998 | 8.107922051919344 |
| RemoveGrain | rg | u16 | mode=4 | 802.06 | 830.93 | 816.54 | 816.5099999999999 | 11.786147235914997 |
| RemoveGrain | std | u16 | mode=4 | 1709.07 | 1719.03 | 1715.78 | 1714.6266666666668 | 4.147130199172558 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1321.46 | 1323.99 | 1323.66 | 1323.0366666666666 | 1.122982140948328 |
| RemoveGrain | rg | u16 | mode=12 | 1467.93 | 1472.49 | 1471.65 | 1470.6899999999998 | 1.9815145722401217 |
| RemoveGrain | std | u16 | mode=12 | 1320.74 | 1327.68 | 1324.11 | 1324.1766666666665 | 2.833635278028741 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1725.57 | 1727.67 | 1726.75 | 1726.6633333333332 | 0.8595089037093512 |
| RemoveGrain | rg | u16 | mode=17 | 1113.44 | 1117.35 | 1114.07 | 1114.9533333333334 | 1.7141048846425333 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1204.68 | 1206.44 | 1204.82 | 1205.3133333333333 | 0.7987212001415704 |
| RemoveGrain | rg | u16 | mode=20 | 704.64 | 705.76 | 705.08 | 705.16 | 0.46072406781789205 |
| RemoveGrain | std | u16 | mode=20 | 1322.56 | 1328.54 | 1324.7 | 1325.2666666666667 | 2.473989131387247 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1495.56 | 1497.74 | 1496.93 | 1496.743333333333 | 0.8997160045753025 |
| RemoveGrain | rg | u16 | mode=22 | 1432.63 | 1445.77 | 1435.66 | 1438.0199999999998 | 5.617953363992922 |
| RemoveGrain | zsmooth | f32 | mode=1 | 621.6 | 622.79 | 622.38 | 622.2566666666667 | 0.49358101890388667 |
| RemoveGrain | rg | f32 | mode=1 | 213.44 | 213.58 | 213.5 | 213.50666666666666 | 0.05734883511362372 |
| RemoveGrain | zsmooth | f32 | mode=4 | 465.68 | 467.81 | 466.41 | 466.6333333333334 | 0.8837923335766624 |
| RemoveGrain | rg | f32 | mode=4 | 64.99 | 65.05 | 65.02 | 65.02 | 0.02449489742783271 |
| RemoveGrain | std | f32 | mode=4 | 723.33 | 727.07 | 725.39 | 725.2633333333333 | 1.5294734024784136 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1054.07 | 1055.82 | 1055.41 | 1055.1000000000001 | 0.7473062736701043 |
| RemoveGrain | rg | f32 | mode=12 | 341.77 | 342.03 | 341.84 | 341.87999999999994 | 0.1098483803552239 |
| RemoveGrain | std | f32 | mode=12 | 1134.63 | 1140.53 | 1136.68 | 1137.28 | 2.4457446037283592 |
| RemoveGrain | zsmooth | f32 | mode=17 | 674.96 | 675.71 | 675.49 | 675.3866666666667 | 0.3147838764754113 |
| RemoveGrain | rg | f32 | mode=17 | 191.21 | 191.45 | 191.42 | 191.35999999999999 | 0.10677078252030385 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1078.6 | 1087.68 | 1082.55 | 1082.9433333333334 | 3.717313844999195 |
| RemoveGrain | rg | f32 | mode=20 | 357.44 | 358.48 | 358.39 | 358.1033333333333 | 0.47048438396567266 |
| RemoveGrain | std | f32 | mode=20 | 1132.66 | 1138.22 | 1134.32 | 1135.0666666666666 | 2.3304553679961733 |
| RemoveGrain | zsmooth | f32 | mode=22 | 903.8 | 904.15 | 904.12 | 904.0233333333334 | 0.15839472494023918 |
| RemoveGrain | rg | f32 | mode=22 | 158.53 | 158.71 | 158.58 | 158.60666666666668 | 0.07586537784494204 |
| Repair | zsmooth | u8 | mode=1 | 1502.84 | 1503.63 | 1503.3 | 1503.256666666667 | 0.3239684483952166 |
| Repair | rg | u8 | mode=1 | 782.95 | 786.44 | 786.28 | 785.2233333333334 | 1.6088159897542182 |
| Repair | zsmooth | u8 | mode=12 | 1328.26 | 1329.98 | 1329.85 | 1329.3633333333332 | 0.7819775501182074 |
| Repair | rg | u8 | mode=12 | 592.26 | 593.39 | 592.95 | 592.8666666666667 | 0.46506869265613904 |
| Repair | zsmooth | u8 | mode=13 | 1327.81 | 1328.54 | 1328.21 | 1328.1866666666667 | 0.29847761874032464 |
| Repair | rg | u8 | mode=13 | 586.84 | 587.41 | 586.94 | 587.0633333333334 | 0.2485066509281773 |
| Repair | zsmooth | u16 | mode=1 | 918.69 | 919.93 | 919.67 | 919.43 | 0.5339163480046444 |
| Repair | rg | u16 | mode=1 | 727.3 | 728.18 | 727.83 | 727.77 | 0.3617549815367701 |
| Repair | zsmooth | u16 | mode=12 | 858.21 | 862.73 | 861.02 | 860.6533333333333 | 1.86340786970777 |
| Repair | rg | u16 | mode=12 | 571.57 | 572.04 | 571.73 | 571.7800000000001 | 0.1951068083554563 |
| Repair | zsmooth | u16 | mode=13 | 857.5 | 863.71 | 861.12 | 860.7766666666666 | 2.546819367149732 |
| Repair | rg | u16 | mode=13 | 565.7 | 569.53 | 567.15 | 567.4599999999999 | 1.5788814606127277 |
| Repair | zsmooth | f32 | mode=1 | 418.98 | 419.54 | 419.41 | 419.31 | 0.23930454794396921 |
| Repair | rg | f32 | mode=1 | 173.03 | 173.07 | 173.04 | 173.04666666666665 | 0.0169967317119735 |
| Repair | zsmooth | f32 | mode=12 | 335.9 | 336.34 | 335.98 | 336.0733333333333 | 0.19136933459208993 |
| Repair | rg | f32 | mode=12 | 61.4 | 61.41 | 61.4 | 61.40333333333333 | 0.004714045207909379 |
| Repair | zsmooth | f32 | mode=13 | 335.58 | 336.25 | 335.9 | 335.91 | 0.27361773821642177 |
| Repair | rg | f32 | mode=13 | 61.57 | 61.59 | 61.58 | 61.580000000000005 | 0.008164965809278536 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1536.22 | 1566.97 | 1554.02 | 1552.4033333333334 | 12.605576367447682 |
| DegrainMedian | dgm | u8 | mode=0 | 179.3 | 179.33 | 179.33 | 179.32000000000002 | 0.014142135623731487 |
| DegrainMedian | zsmooth | u8 | mode=1 | 431.6 | 431.99 | 431.79 | 431.79333333333335 | 0.1592342788332769 |
| DegrainMedian | dgm | u8 | mode=1 | 453.06 | 453.27 | 453.07 | 453.1333333333334 | 0.09672412085697174 |
| DegrainMedian | zsmooth | u8 | mode=2 | 431.49 | 432.55 | 432.25 | 432.09666666666664 | 0.44611906731524265 |
| DegrainMedian | dgm | u8 | mode=2 | 469.46 | 469.65 | 469.58 | 469.56333333333333 | 0.07845734863959827 |
| DegrainMedian | zsmooth | u8 | mode=3 | 428.76 | 428.85 | 428.77 | 428.79333333333335 | 0.04027681991199859 |
| DegrainMedian | dgm | u8 | mode=3 | 491.11 | 491.28 | 491.13 | 491.17333333333335 | 0.07586537784492456 |
| DegrainMedian | zsmooth | u8 | mode=4 | 429.94 | 430.53 | 430.06 | 430.1766666666667 | 0.2546020860523652 |
| DegrainMedian | dgm | u8 | mode=4 | 471.94 | 472.09 | 471.99 | 472.00666666666666 | 0.062360956446221215 |
| DegrainMedian | zsmooth | u8 | mode=5 | 294.26 | 294.41 | 294.33 | 294.3333333333333 | 0.061282587702848466 |
| DegrainMedian | dgm | u8 | mode=5 | 560.01 | 560.34 | 560.22 | 560.19 | 0.13638181696987622 |
| DegrainMedian | zsmooth | u16 | mode=0 | 644.65 | 645.99 | 645.79 | 645.4766666666667 | 0.5902165327704432 |
| DegrainMedian | dgm | u16 | mode=0 | 85.16 | 85.18 | 85.17 | 85.17 | 0.008164965809281437 |
| DegrainMedian | zsmooth | u16 | mode=1 | 184.75 | 184.83 | 184.75 | 184.77666666666667 | 0.03771236166328843 |
| DegrainMedian | dgm | u16 | mode=1 | 96.02 | 96.04 | 96.03 | 96.03000000000002 | 0.008164965809281437 |
| DegrainMedian | zsmooth | u16 | mode=2 | 185.43 | 185.49 | 185.49 | 185.47000000000003 | 0.028284271247462973 |
| DegrainMedian | dgm | u16 | mode=2 | 110.29 | 110.3 | 110.29 | 110.29333333333334 | 0.004714045207906029 |
| DegrainMedian | zsmooth | u16 | mode=3 | 193.96 | 194.09 | 193.98 | 194.01 | 0.057154760664941885 |
| DegrainMedian | dgm | u16 | mode=3 | 126.76 | 126.78 | 126.77 | 126.77 | 0.008164965809275636 |
| DegrainMedian | zsmooth | u16 | mode=4 | 182.69 | 182.72 | 182.69 | 182.70000000000002 | 0.014142135623731487 |
| DegrainMedian | dgm | u16 | mode=4 | 106.16 | 106.18 | 106.16 | 106.16666666666667 | 0.009428090415825457 |
| DegrainMedian | zsmooth | u16 | mode=5 | 138.12 | 138.18 | 138.14 | 138.14666666666668 | 0.024944382578495575 |
| DegrainMedian | dgm | u16 | mode=5 | 163.06 | 163.14 | 163.07 | 163.09 | 0.03559026084009862 |
| DegrainMedian | zsmooth | f32 | mode=0 | 244.63 | 245.55 | 245.24 | 245.14000000000001 | 0.38218669085496937 |
| DegrainMedian | zsmooth | f32 | mode=1 | 84.08 | 84.36 | 84.18 | 84.20666666666666 | 0.11585431464655163 |
| DegrainMedian | zsmooth | f32 | mode=2 | 92.28 | 92.44 | 92.32 | 92.34666666666665 | 0.06798692684790328 |
| DegrainMedian | zsmooth | f32 | mode=3 | 94.53 | 94.62 | 94.62 | 94.58999999999999 | 0.042426406871194464 |
| DegrainMedian | zsmooth | f32 | mode=4 | 90.55 | 90.7 | 90.57 | 90.60666666666667 | 0.0664997911442034 |
| DegrainMedian | zsmooth | f32 | mode=5 | 116.44 | 116.61 | 116.45 | 116.5 | 0.07788880963698586 |
| InterQuartileMean | zsmooth | u8 |  | 1425.2 | 1426.64 | 1426.09 | 1425.9766666666667 | 0.5933146064460546 |
| InterQuartileMean | zsmooth | u16 |  | 668.03 | 669.88 | 668.05 | 668.6533333333333 | 0.8674227471205999 |
| InterQuartileMean | zsmooth | f32 |  | 316.12 | 316.36 | 316.18 | 316.21999999999997 | 0.10198039027185957 |
