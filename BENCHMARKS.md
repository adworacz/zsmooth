# Benchmarks
All benchmarks are run single-threaded (`core.num_threads = 1`) with a max cache size of 1GB (`core.max_cache_size = 1024`) 
to provided the greatest stability of FPS numbers between runs. 

So while the benchmarks show fast results, you'll see even faster by using Zsmooth when using a fully threaded VapourSynth script.

## Table of Contents
* [0.12 - Zig 0.14.1 - ARM NEON](#012---zig-0141---arm-neon-aarch64-macos)
* [0.12 - Zig 0.14.1 - AVX512](#012---zig-0141---avx512)
* [0.12 - Zig 0.14.1 - AVX2](#012---zig-0141---avx2)
* [0.10 - Zig 0.14.1 - ARM NEON](#010---zig-0141---arm-neon-aarch64-macos)
* [0.10 - Zig 0.14.1 - AVX512](#010---zig-0141---avx512)
* [0.10 - Zig 0.14.1 - AVX2](#010---zig-0141---avx2)
* [0.9 - Zig 0.14.0 - ARM NEON](#09---zig-0140---arm-neon-aarch64-macos)
* [0.9 - Zig 0.14.0 - AVX512](#09---zig-0140---avx512-znver4)
* [0.9 - Zig 0.14.0 - AVX2](#09---zig-0140---avx2)
* [0.9 - Zig 0.12.1 - AVX2](#09---zig-0121---avx2)

## 0.12 - Zig 0.14.1 - ARM NEON (aarch64-macos)
Source: BlankClip YUV420\*, 1920x1080

Machine: M4 Mac Mini, 16GB

OS: Darwin Mac.lan 24.5.0 Darwin Kernel Version 24.5.0: Tue Apr 22 19:54:43 PDT 2025; root:xnu-11417.121.6~2/RELEASE_ARM64_T8132 arm64  

CPU tuning: aarch64-macos

\* Some filters (CCD) require RGB input, so bit depth-specific RGB is used in those cases.

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CCD | zsmooth | u8 | temporal_radius=0 | 123.08 | 124.21 | 123.62 | 123.637 | 0.461 |
| CCD | zsmooth | u8 | temporal_radius=3 | 11.49 | 11.79 | 11.51 | 11.597 | 0.137 |
| CCD | zsmooth | u16 | temporal_radius=0 | 39.8 | 39.86 | 39.82 | 39.827 | 0.025 |
| CCD | zsmooth | u16 | temporal_radius=3 | 5.1 | 5.11 | 5.11 | 5.107 | 0.005 |
| CCD | zsmooth | f32 | temporal_radius=0 | 72.1 | 73.2 | 72.84 | 72.713 | 0.458 |
| CCD | zsmooth | f32 | temporal_radius=3 | 12.93 | 13.22 | 13.14 | 13.097 | 0.122 |
| CCD | ccd | f32 | temporal_radius=0 | 30.95 | 32.3 | 31.5 | 31.583 | 0.554 |
| Clense | zsmooth | u8 | function=Clense | 5268.6 | 6669.44 | 5772.55 | 5903.530 | 579.342 |
| Clense | rg | u8 | function=Clense | 6598.06 | 6657.13 | 6628.71 | 6627.967 | 24.121 |
| Clense | zsmooth | u8 | function=ForwardClense | 5821.17 | 6365.79 | 5891.89 | 6026.283 | 241.797 |
| Clense | rg | u8 | function=ForwardClense | 1197.85 | 1258.29 | 1255.62 | 1237.253 | 27.884 |
| Clense | zsmooth | u8 | function=BackwardClense | 6312.67 | 6406.57 | 6342.24 | 6353.827 | 39.200 |
| Clense | rg | u8 | function=BackwardClense | 1262.19 | 1275.43 | 1273.48 | 1270.367 | 5.836 |
| Clense | zsmooth | u16 | function=Clense | 879.18 | 881.13 | 880.9 | 880.403 | 0.870 |
| Clense | rg | u16 | function=Clense | 851.64 | 875.57 | 867.55 | 864.920 | 9.945 |
| Clense | zsmooth | u16 | function=ForwardClense | 869.74 | 873.15 | 872.9 | 871.930 | 1.552 |
| Clense | rg | u16 | function=ForwardClense | 646 | 649.17 | 647.54 | 647.570 | 1.294 |
| Clense | zsmooth | u16 | function=BackwardClense | 873.12 | 874.94 | 874.2 | 874.087 | 0.747 |
| Clense | rg | u16 | function=BackwardClense | 642.17 | 648.44 | 646.95 | 645.853 | 2.675 |
| Clense | zsmooth | f32 | function=Clense | 735.72 | 749.71 | 739.4 | 741.610 | 5.921 |
| Clense | rg | f32 | function=Clense | 732.24 | 753 | 740.16 | 741.800 | 8.554 |
| Clense | zsmooth | f32 | function=ForwardClense | 740.01 | 759.75 | 740.51 | 746.757 | 9.190 |
| Clense | rg | f32 | function=ForwardClense | 380.22 | 383.23 | 382.05 | 381.833 | 1.238 |
| Clense | zsmooth | f32 | function=BackwardClense | 736.95 | 755.33 | 739.54 | 743.940 | 8.123 |
| Clense | rg | f32 | function=BackwardClense | 379.85 | 383.61 | 381.95 | 381.803 | 1.539 |
| DegrainMedian | zsmooth | u8 | mode=0 | 781.14 | 782.78 | 781.18 | 781.700 | 0.764 |
| DegrainMedian | dgm | u8 | mode=0 | 156.27 | 157.23 | 156.97 | 156.823 | 0.405 |
| DegrainMedian | zsmooth | u8 | mode=1 | 222.11 | 222.37 | 222.19 | 222.223 | 0.109 |
| DegrainMedian | dgm | u8 | mode=1 | 84.42 | 84.55 | 84.5 | 84.490 | 0.054 |
| DegrainMedian | zsmooth | u8 | mode=2 | 221.39 | 221.67 | 221.52 | 221.527 | 0.114 |
| DegrainMedian | dgm | u8 | mode=2 | 84.21 | 84.39 | 84.24 | 84.280 | 0.079 |
| DegrainMedian | zsmooth | u8 | mode=3 | 237.16 | 237.32 | 237.31 | 237.263 | 0.073 |
| DegrainMedian | dgm | u8 | mode=3 | 87.6 | 87.96 | 87.94 | 87.833 | 0.165 |
| DegrainMedian | zsmooth | u8 | mode=4 | 221.46 | 222.07 | 221.69 | 221.740 | 0.252 |
| DegrainMedian | dgm | u8 | mode=4 | 83.27 | 83.41 | 83.39 | 83.357 | 0.062 |
| DegrainMedian | zsmooth | u8 | mode=5 | 215.67 | 216.34 | 215.74 | 215.917 | 0.301 |
| DegrainMedian | dgm | u8 | mode=5 | 112.04 | 112.21 | 112.16 | 112.137 | 0.071 |
| DegrainMedian | zsmooth | u16 | mode=0 | 242.83 | 243.65 | 243.14 | 243.207 | 0.338 |
| DegrainMedian | dgm | u16 | mode=0 | 139.46 | 139.75 | 139.6 | 139.603 | 0.118 |
| DegrainMedian | zsmooth | u16 | mode=1 | 98.79 | 98.96 | 98.95 | 98.900 | 0.078 |
| DegrainMedian | dgm | u16 | mode=1 | 81.3 | 81.61 | 81.44 | 81.450 | 0.127 |
| DegrainMedian | zsmooth | u16 | mode=2 | 98.77 | 98.94 | 98.93 | 98.880 | 0.078 |
| DegrainMedian | dgm | u16 | mode=2 | 81.32 | 81.61 | 81.51 | 81.480 | 0.120 |
| DegrainMedian | zsmooth | u16 | mode=3 | 105.11 | 105.16 | 105.14 | 105.137 | 0.021 |
| DegrainMedian | dgm | u16 | mode=3 | 85.79 | 86.11 | 86.04 | 85.980 | 0.137 |
| DegrainMedian | zsmooth | u16 | mode=4 | 98.5 | 98.53 | 98.51 | 98.513 | 0.012 |
| DegrainMedian | dgm | u16 | mode=4 | 81.37 | 81.44 | 81.38 | 81.397 | 0.031 |
| DegrainMedian | zsmooth | u16 | mode=5 | 95 | 95.1 | 95.06 | 95.053 | 0.041 |
| DegrainMedian | dgm | u16 | mode=5 | 100.38 | 100.5 | 100.46 | 100.447 | 0.050 |
| DegrainMedian | zsmooth | f32 | mode=0 | 131.19 | 131.73 | 131.68 | 131.533 | 0.244 |
| DegrainMedian | zsmooth | f32 | mode=1 | 72.81 | 72.92 | 72.82 | 72.850 | 0.050 |
| DegrainMedian | zsmooth | f32 | mode=2 | 79.63 | 80.04 | 79.79 | 79.820 | 0.169 |
| DegrainMedian | zsmooth | f32 | mode=3 | 83.97 | 84.1 | 84.02 | 84.030 | 0.054 |
| DegrainMedian | zsmooth | f32 | mode=4 | 79.21 | 79.5 | 79.37 | 79.360 | 0.119 |
| DegrainMedian | zsmooth | f32 | mode=5 | 99.2 | 99.73 | 99.58 | 99.503 | 0.223 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1489.66 | 1493.65 | 1493.18 | 1492.163 | 1.780 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 583.69 | 585.24 | 584.77 | 584.567 | 0.649 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 665.6 | 666.38 | 666.32 | 666.100 | 0.354 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 301.01 | 302.87 | 302.51 | 302.130 | 0.805 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 573.96 | 574.61 | 574.58 | 574.383 | 0.300 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 378.06 | 378.92 | 378.7 | 378.560 | 0.365 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 322.46 | 322.74 | 322.49 | 322.563 | 0.126 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 230.31 | 230.91 | 230.65 | 230.623 | 0.246 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 339.68 | 340.95 | 340.62 | 340.417 | 0.538 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 105.62 | 106.15 | 105.88 | 105.883 | 0.216 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 366.17 | 406.44 | 393.82 | 388.810 | 16.818 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 182.86 | 189.1 | 184.37 | 185.443 | 2.658 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 52.63 | 52.8 | 52.8 | 52.743 | 0.080 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 297.74 | 305.24 | 300.77 | 301.250 | 3.081 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 117.27 | 118.17 | 117.89 | 117.777 | 0.376 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 29.66 | 29.69 | 29.69 | 29.680 | 0.014 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 147.47 | 150.75 | 148.43 | 148.883 | 1.377 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 35.59 | 35.61 | 35.59 | 35.597 | 0.009 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 11.61 | 11.62 | 11.61 | 11.613 | 0.005 |
| Median | zsmooth | u8 | radius=1 | 1953.28 | 2020.51 | 1971.59 | 1981.793 | 28.379 |
| Median | std | u8 | radius=1 | 56.46 | 56.47 | 56.46 | 56.463 | 0.005 |
| Median | ctmf | u8 | radius=1 | 18.44 | 18.47 | 18.45 | 18.453 | 0.012 |
| Median | zsmooth | u8 | radius=2 | 450.31 | 452.29 | 451.34 | 451.313 | 0.809 |
| Median | ctmf | u8 | radius=2 | 459.6 | 461.27 | 459.91 | 460.260 | 0.725 |
| Median | zsmooth | u8 | radius=3 | 84.95 | 85.06 | 85 | 85.003 | 0.045 |
| Median | ctmf | u8 | radius=3 | 18.32 | 18.38 | 18.37 | 18.357 | 0.026 |
| Median | zsmooth | u16 | radius=1 | 508.46 | 510.76 | 509.04 | 509.420 | 0.977 |
| Median | std | u16 | radius=1 | 53.1 | 53.27 | 53.22 | 53.197 | 0.071 |
| Median | ctmf | u16 | radius=1 | 0.37 | 0.37 | 0.37 | 0.370 | 0.000 |
| Median | zsmooth | u16 | radius=2 | 193.69 | 194.06 | 193.77 | 193.840 | 0.159 |
| Median | ctmf | u16 | radius=2 | 188.35 | 189.72 | 189.3 | 189.123 | 0.573 |
| Median | zsmooth | u16 | radius=3 | 43.14 | 43.25 | 43.21 | 43.200 | 0.045 |
| Median | ctmf | u16 | radius=3 | 0.08 | 0.08 | 0.08 | 0.080 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 246.47 | 251.79 | 248.8 | 249.020 | 2.177 |
| Median | std | f32 | radius=1 | 80 | 80.39 | 80.28 | 80.223 | 0.164 |
| Median | zsmooth | f32 | radius=2 | 51.4 | 51.45 | 51.44 | 51.430 | 0.022 |
| Median | ctmf | f32 | radius=2 | 52.18 | 52.22 | 52.21 | 52.203 | 0.017 |
| Median | zsmooth | f32 | radius=3 | 18.5 | 18.53 | 18.51 | 18.513 | 0.012 |
| RemoveGrain | zsmooth | u8 | mode=1 | 2470.3 | 2782.21 | 2765.83 | 2672.780 | 143.331 |
| RemoveGrain | rg | u8 | mode=1 | 724.05 | 729.27 | 728.28 | 727.200 | 2.264 |
| RemoveGrain | zsmooth | u8 | mode=4 | 1853.71 | 1943.6 | 1919.32 | 1905.543 | 37.968 |
| RemoveGrain | rg | u8 | mode=4 | 51.86 | 52.95 | 52.28 | 52.363 | 0.449 |
| RemoveGrain | std | u8 | mode=4 | 56.37 | 56.39 | 56.38 | 56.380 | 0.008 |
| RemoveGrain | zsmooth | u8 | mode=12 | 2213.83 | 2628.69 | 2606.87 | 2483.130 | 190.632 |
| RemoveGrain | rg | u8 | mode=12 | 882.92 | 908.02 | 894.35 | 895.097 | 10.261 |
| RemoveGrain | std | u8 | mode=12 | 152.11 | 153.9 | 153.7 | 153.237 | 0.801 |
| RemoveGrain | zsmooth | u8 | mode=17 | 2538.45 | 2704.21 | 2556.71 | 2599.790 | 74.211 |
| RemoveGrain | rg | u8 | mode=17 | 679.38 | 683.8 | 681.21 | 681.463 | 1.813 |
| RemoveGrain | zsmooth | u8 | mode=20 | 1793.09 | 2045.63 | 1980.42 | 1939.713 | 107.042 |
| RemoveGrain | rg | u8 | mode=20 | 1534.83 | 2171.57 | 1843.9 | 1850.100 | 259.985 |
| RemoveGrain | std | u8 | mode=20 | 153.35 | 154.05 | 153.44 | 153.613 | 0.311 |
| RemoveGrain | zsmooth | u8 | mode=22 | 1912.33 | 1997.23 | 1963.53 | 1957.697 | 34.905 |
| RemoveGrain | rg | u8 | mode=22 | 577.82 | 581.56 | 580.02 | 579.800 | 1.535 |
| RemoveGrain | zsmooth | u16 | mode=1 | 574.88 | 576.32 | 576.14 | 575.780 | 0.641 |
| RemoveGrain | rg | u16 | mode=1 | 409.01 | 414.52 | 412.92 | 412.150 | 2.314 |
| RemoveGrain | zsmooth | u16 | mode=4 | 486.69 | 488.87 | 487.72 | 487.760 | 0.890 |
| RemoveGrain | rg | u16 | mode=4 | 48.44 | 50.14 | 48.95 | 49.177 | 0.712 |
| RemoveGrain | std | u16 | mode=4 | 53.17 | 53.19 | 53.19 | 53.183 | 0.009 |
| RemoveGrain | zsmooth | u16 | mode=12 | 553.57 | 559.14 | 557.5 | 556.737 | 2.337 |
| RemoveGrain | rg | u16 | mode=12 | 542.85 | 543.97 | 543.83 | 543.550 | 0.498 |
| RemoveGrain | std | u16 | mode=12 | 88.47 | 89.27 | 88.95 | 88.897 | 0.329 |
| RemoveGrain | zsmooth | u16 | mode=17 | 578.19 | 581.75 | 578.54 | 579.493 | 1.602 |
| RemoveGrain | rg | u16 | mode=17 | 395.06 | 396.44 | 395.12 | 395.540 | 0.637 |
| RemoveGrain | zsmooth | u16 | mode=20 | 400.48 | 403.05 | 401.09 | 401.540 | 1.096 |
| RemoveGrain | rg | u16 | mode=20 | 403.21 | 409.03 | 405.82 | 406.020 | 2.380 |
| RemoveGrain | std | u16 | mode=20 | 88.79 | 89.03 | 88.86 | 88.893 | 0.101 |
| RemoveGrain | zsmooth | u16 | mode=22 | 503.1 | 509.41 | 506.3 | 506.270 | 2.576 |
| RemoveGrain | rg | u16 | mode=22 | 484.33 | 495.81 | 492.46 | 490.867 | 4.820 |
| RemoveGrain | zsmooth | f32 | mode=1 | 490.48 | 517.35 | 504.99 | 504.273 | 10.981 |
| RemoveGrain | rg | f32 | mode=1 | 501.22 | 506.62 | 506.49 | 504.777 | 2.516 |
| RemoveGrain | zsmooth | f32 | mode=4 | 375.05 | 389.4 | 385.75 | 383.400 | 6.089 |
| RemoveGrain | rg | f32 | mode=4 | 47.52 | 47.99 | 47.89 | 47.800 | 0.202 |
| RemoveGrain | std | f32 | mode=4 | 79.09 | 79.36 | 79.2 | 79.217 | 0.111 |
| RemoveGrain | zsmooth | f32 | mode=12 | 490.04 | 508.81 | 499.64 | 499.497 | 7.663 |
| RemoveGrain | rg | f32 | mode=12 | 330.16 | 337.67 | 335.38 | 334.403 | 3.143 |
| RemoveGrain | std | f32 | mode=12 | 223.18 | 230.47 | 227.44 | 227.030 | 2.990 |
| RemoveGrain | zsmooth | f32 | mode=17 | 491.48 | 500.56 | 492.98 | 495.007 | 3.974 |
| RemoveGrain | rg | f32 | mode=17 | 469.88 | 481.72 | 470.7 | 474.100 | 5.399 |
| RemoveGrain | zsmooth | f32 | mode=20 | 498.43 | 504.84 | 500.86 | 501.377 | 2.642 |
| RemoveGrain | rg | f32 | mode=20 | 343 | 347.84 | 347.14 | 345.993 | 2.136 |
| RemoveGrain | std | f32 | mode=20 | 221.74 | 234.16 | 228.42 | 228.107 | 5.075 |
| RemoveGrain | zsmooth | f32 | mode=22 | 490.41 | 515.52 | 506.07 | 504.000 | 10.355 |
| RemoveGrain | rg | f32 | mode=22 | 253.36 | 258.88 | 254.77 | 255.670 | 2.342 |
| Repair | zsmooth | u8 | mode=1 | 2091.57 | 2256.2 | 2233.87 | 2193.880 | 72.916 |
| Repair | rg | u8 | mode=1 | 635.82 | 647.46 | 644.01 | 642.430 | 4.882 |
| Repair | zsmooth | u8 | mode=12 | 1524.43 | 1546.61 | 1539.99 | 1537.010 | 9.297 |
| Repair | rg | u8 | mode=12 | 51.72 | 52.6 | 52.36 | 52.227 | 0.371 |
| Repair | zsmooth | u8 | mode=13 | 1512.96 | 1578.31 | 1575.21 | 1555.493 | 30.102 |
| Repair | rg | u8 | mode=13 | 50.24 | 51.3 | 51.22 | 50.920 | 0.482 |
| Repair | zsmooth | u16 | mode=1 | 541.47 | 549.76 | 544.68 | 545.303 | 3.413 |
| Repair | rg | u16 | mode=1 | 379.25 | 380.43 | 380.41 | 380.030 | 0.552 |
| Repair | zsmooth | u16 | mode=12 | 455.17 | 459.46 | 457.07 | 457.233 | 1.755 |
| Repair | rg | u16 | mode=12 | 48.79 | 49.35 | 48.86 | 49.000 | 0.249 |
| Repair | zsmooth | u16 | mode=13 | 457.6 | 468.32 | 459.32 | 461.747 | 4.701 |
| Repair | rg | u16 | mode=13 | 48.97 | 49.61 | 49.49 | 49.357 | 0.278 |
| Repair | zsmooth | f32 | mode=1 | 468.09 | 482.63 | 468.22 | 472.980 | 6.824 |
| Repair | rg | f32 | mode=1 | 461.55 | 486.1 | 464.08 | 470.577 | 11.025 |
| Repair | zsmooth | f32 | mode=12 | 361.53 | 366.64 | 365.93 | 364.700 | 2.260 |
| Repair | rg | f32 | mode=12 | 47.48 | 48.48 | 47.79 | 47.917 | 0.418 |
| Repair | zsmooth | f32 | mode=13 | 362.3 | 366.67 | 363.83 | 364.267 | 1.811 |
| Repair | rg | f32 | mode=13 | 48.23 | 48.7 | 48.34 | 48.423 | 0.201 |
| SmartMedian | zsmooth | u8 | radius=1 | 369.46 | 372.21 | 372.02 | 371.230 | 1.254 |
| SmartMedian | zsmooth | u8 | radius=2 | 151.57 | 154.83 | 154.39 | 153.597 | 1.444 |
| SmartMedian | zsmooth | u8 | radius=3 | 47.04 | 47.08 | 47.07 | 47.063 | 0.017 |
| SmartMedian | zsmooth | u16 | radius=1 | 235 | 246.48 | 246.36 | 242.613 | 5.384 |
| SmartMedian | zsmooth | u16 | radius=2 | 111.07 | 113.65 | 112.68 | 112.467 | 1.064 |
| SmartMedian | zsmooth | u16 | radius=3 | 26.42 | 26.44 | 26.43 | 26.430 | 0.008 |
| SmartMedian | zsmooth | f32 | radius=1 | 130.88 | 134.77 | 133.24 | 132.963 | 1.600 |
| SmartMedian | zsmooth | f32 | radius=2 | 39.89 | 40.01 | 39.98 | 39.960 | 0.051 |
| SmartMedian | zsmooth | f32 | radius=3 | 10.99 | 11 | 11 | 10.997 | 0.005 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6518.16 | 6598.14 | 6589.8 | 6568.700 | 35.899 |
| TemporalMedian | tmedian | u8 | radius=1 | 97.91 | 98.56 | 98.41 | 98.293 | 0.278 |
| TemporalMedian | zsmooth | u8 | radius=10 | 388.88 | 391.24 | 390.11 | 390.077 | 0.964 |
| TemporalMedian | tmedian | u8 | radius=10 | 16.49 | 17.33 | 17.31 | 17.043 | 0.391 |
| TemporalMedian | zsmooth | u16 | radius=1 | 853.85 | 855.96 | 854.99 | 854.933 | 0.862 |
| TemporalMedian | tmedian | u16 | radius=1 | 88.48 | 88.8 | 88.58 | 88.620 | 0.134 |
| TemporalMedian | zsmooth | u16 | radius=10 | 182.54 | 183.98 | 182.79 | 183.103 | 0.628 |
| TemporalMedian | tmedian | u16 | radius=10 | 18.49 | 18.55 | 18.51 | 18.517 | 0.025 |
| TemporalMedian | zsmooth | f32 | radius=1 | 733.13 | 741.86 | 740.36 | 738.450 | 3.811 |
| TemporalMedian | tmedian | f32 | radius=1 | 81.61 | 85.9 | 83.79 | 83.767 | 1.751 |
| TemporalMedian | zsmooth | f32 | radius=10 | 66.89 | 67.14 | 66.97 | 67.000 | 0.104 |
| TemporalMedian | tmedian | f32 | radius=10 | 21.39 | 21.66 | 21.53 | 21.527 | 0.110 |
| TemporalRepair | zsmooth | u8 | mode=0 | 6168.17 | 6178.68 | 6170.64 | 6172.497 | 4.487 |
| TemporalRepair | zsmooth | u8 | mode=1 | 1072.66 | 1079.99 | 1073.79 | 1075.480 | 3.222 |
| TemporalRepair | zsmooth | u8 | mode=2 | 970.49 | 972 | 971.48 | 971.323 | 0.626 |
| TemporalRepair | zsmooth | u8 | mode=3 | 913.15 | 922.15 | 915.56 | 916.953 | 3.804 |
| TemporalRepair | zsmooth | u8 | mode=4 | 254.03 | 255.1 | 254.71 | 254.613 | 0.442 |
| TemporalRepair | zsmooth | u16 | mode=0 | 831.54 | 832.89 | 832.28 | 832.237 | 0.552 |
| TemporalRepair | zsmooth | u16 | mode=1 | 300.89 | 301.97 | 301.65 | 301.503 | 0.453 |
| TemporalRepair | zsmooth | u16 | mode=2 | 292.99 | 294.31 | 293.87 | 293.723 | 0.549 |
| TemporalRepair | zsmooth | u16 | mode=3 | 297.47 | 298.91 | 297.81 | 298.063 | 0.615 |
| TemporalRepair | zsmooth | u16 | mode=4 | 164.41 | 165.12 | 164.56 | 164.697 | 0.306 |
| TemporalRepair | zsmooth | f32 | mode=0 | 680.67 | 689.49 | 688.05 | 686.070 | 3.863 |
| TemporalRepair | zsmooth | f32 | mode=1 | 174.24 | 178.76 | 176.61 | 176.537 | 1.846 |
| TemporalRepair | zsmooth | f32 | mode=2 | 173.95 | 177.26 | 174.81 | 175.340 | 1.402 |
| TemporalRepair | zsmooth | f32 | mode=3 | 189.95 | 191.48 | 190.57 | 190.667 | 0.628 |
| TemporalRepair | zsmooth | f32 | mode=4 | 214.09 | 214.91 | 214.78 | 214.593 | 0.360 |
| TemporalSoften | zsmooth | u8 | radius=1 | 2862.3 | 2864.48 | 2862.64 | 2863.140 | 0.958 |
| TemporalSoften | std | u8 | radius=1 | 277.19 | 277.33 | 277.26 | 277.260 | 0.057 |
| TemporalSoften | zsmooth | u8 | radius=7 | 609.36 | 612.53 | 611.93 | 611.273 | 1.375 |
| TemporalSoften | std | u8 | radius=7 | 31.86 | 33.05 | 31.94 | 32.283 | 0.543 |
| TemporalSoften | zsmooth | u16 | radius=1 | 539.76 | 542.34 | 540.63 | 540.910 | 1.072 |
| TemporalSoften | std | u16 | radius=1 | 216.16 | 216.81 | 216.6 | 216.523 | 0.271 |
| TemporalSoften | zsmooth | u16 | radius=7 | 231.04 | 231.2 | 231.08 | 231.107 | 0.068 |
| TemporalSoften | std | u16 | radius=7 | 34.34 | 34.55 | 34.5 | 34.463 | 0.090 |
| TemporalSoften | zsmooth | f32 | radius=1 | 436.67 | 441.11 | 439.47 | 439.083 | 1.833 |
| TemporalSoften | std | f32 | radius=1 | 281.84 | 282.9 | 282.53 | 282.423 | 0.439 |
| TemporalSoften | zsmooth | f32 | radius=7 | 75.91 | 76.21 | 75.97 | 76.030 | 0.130 |
| TemporalSoften | std | f32 | radius=7 | 40.45 | 40.68 | 40.51 | 40.547 | 0.097 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 343.74 | 344.31 | 344.13 | 344.060 | 0.238 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 179.4 | 179.94 | 179.45 | 179.597 | 0.244 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 606.46 | 607.25 | 606.64 | 606.783 | 0.338 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 192.86 | 196.47 | 196.22 | 195.183 | 1.646 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 265.49 | 266.93 | 265.79 | 266.070 | 0.620 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 187.56 | 188.42 | 188.35 | 188.110 | 0.390 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 430.36 | 430.98 | 430.46 | 430.600 | 0.272 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 196.76 | 197.36 | 197.19 | 197.103 | 0.252 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 215.6 | 216.77 | 216.11 | 216.160 | 0.479 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 183.45 | 184.62 | 183.55 | 183.873 | 0.530 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 350 | 352.53 | 351.07 | 351.200 | 1.037 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 207.3 | 209.1 | 209 | 208.467 | 0.826 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 5779.25 | 6014.27 | 5964.8 | 5919.440 | 101.166 |
| VerticalCleaner | rg | u8 | mode=1 | 5680.93 | 6047.15 | 5866.51 | 5864.863 | 149.513 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 2621.32 | 2635.92 | 2629.17 | 2628.803 | 5.966 |
| VerticalCleaner | rg | u8 | mode=2 | 450.51 | 452.08 | 451.44 | 451.343 | 0.645 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 927.86 | 930.97 | 930.61 | 929.813 | 1.389 |
| VerticalCleaner | rg | u16 | mode=1 | 926.31 | 932.02 | 926.72 | 928.350 | 2.600 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 665.04 | 667.77 | 667.59 | 666.800 | 1.247 |
| VerticalCleaner | rg | u16 | mode=2 | 332.09 | 332.54 | 332.27 | 332.300 | 0.185 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 853.1 | 858.41 | 855.69 | 855.733 | 2.168 |
| VerticalCleaner | rg | f32 | mode=1 | 861.87 | 867.69 | 864.53 | 864.697 | 2.379 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 403.3 | 406.61 | 405.22 | 405.043 | 1.357 |
| VerticalCleaner | rg | f32 | mode=2 | 180.54 | 181.33 | 180.83 | 180.900 | 0.326 |

## 0.12 - Zig 0.14.1 - AVX512
Source: BlankClip YUV420\*, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

OS: Linux fedora 6.14.9-300.fc42.x86_64 #1 SMP PREEMPT_DYNAMIC Thu May 29 14:27:53 UTC 2025 x86_64 GNU/Linux 

CPU tuning: AVX512 (znver4)

\* Some filters (CCD) require RGB input, so bit depth-specific RGB is used in those cases.

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CCD | zsmooth | u8 | temporal_radius=0 | 269.66 | 270.61 | 270.32 | 270.197 | 0.398 |
| CCD | zsmooth | u8 | temporal_radius=3 | 50.22 | 50.56 | 50.43 | 50.403 | 0.140 |
| CCD | zsmooth | u16 | temporal_radius=0 | 196.22 | 198.78 | 197.09 | 197.363 | 1.063 |
| CCD | zsmooth | u16 | temporal_radius=3 | 19.36 | 19.44 | 19.39 | 19.397 | 0.033 |
| CCD | zsmooth | f32 | temporal_radius=0 | 208.94 | 209.81 | 209.2 | 209.317 | 0.365 |
| CCD | zsmooth | f32 | temporal_radius=3 | 32.8 | 32.88 | 32.85 | 32.843 | 0.033 |
| CCD | ccd | f32 | temporal_radius=0 | 28.54 | 28.63 | 28.62 | 28.597 | 0.040 |
| CCD | jetpack | f32 | temporal_radius=0 | 3.61 | 3.61 | 3.61 | 3.610 | 0.000 |
| Clense | zsmooth | u8 | function=Clense | 6874.49 | 6890.61 | 6886.11 | 6883.737 | 6.792 |
| Clense | rg | u8 | function=Clense | 6356.92 | 6399.51 | 6381.76 | 6379.397 | 17.467 |
| Clense | zsmooth | u8 | function=ForwardClense | 6820.88 | 6837.75 | 6837.42 | 6832.017 | 7.876 |
| Clense | rg | u8 | function=ForwardClense | 871.64 | 871.88 | 871.82 | 871.780 | 0.102 |
| Clense | zsmooth | u8 | function=BackwardClense | 6831.56 | 6836.82 | 6835.2 | 6834.527 | 2.200 |
| Clense | rg | u8 | function=BackwardClense | 872.75 | 873.49 | 873.34 | 873.193 | 0.319 |
| Clense | zsmooth | u16 | function=Clense | 1881.77 | 1884.83 | 1883.1 | 1883.233 | 1.253 |
| Clense | rg | u16 | function=Clense | 1469.6 | 1470.2 | 1469.67 | 1469.823 | 0.268 |
| Clense | zsmooth | u16 | function=ForwardClense | 1826.33 | 1832.74 | 1827.66 | 1828.910 | 2.762 |
| Clense | rg | u16 | function=ForwardClense | 546.23 | 546.55 | 546.51 | 546.430 | 0.142 |
| Clense | zsmooth | u16 | function=BackwardClense | 1830.82 | 1846.66 | 1838.81 | 1838.763 | 6.467 |
| Clense | rg | u16 | function=BackwardClense | 546.78 | 547.29 | 547.22 | 547.097 | 0.226 |
| Clense | zsmooth | f32 | function=Clense | 882.19 | 885.91 | 883.85 | 883.983 | 1.522 |
| Clense | rg | f32 | function=Clense | 822.92 | 824.23 | 823.19 | 823.447 | 0.565 |
| Clense | zsmooth | f32 | function=ForwardClense | 886.49 | 895.49 | 895.24 | 892.407 | 4.185 |
| Clense | rg | f32 | function=ForwardClense | 252.2 | 252.38 | 252.24 | 252.273 | 0.077 |
| Clense | zsmooth | f32 | function=BackwardClense | 897.81 | 899.15 | 898.24 | 898.400 | 0.559 |
| Clense | rg | f32 | function=BackwardClense | 251.25 | 252.44 | 252.34 | 252.010 | 0.539 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1857.05 | 1886.14 | 1883.27 | 1875.487 | 13.089 |
| DegrainMedian | dgm | u8 | mode=0 | 178.67 | 178.73 | 178.69 | 178.697 | 0.025 |
| DegrainMedian | zsmooth | u8 | mode=1 | 776.05 | 776.94 | 776.44 | 776.477 | 0.364 |
| DegrainMedian | dgm | u8 | mode=1 | 458.43 | 458.72 | 458.66 | 458.603 | 0.125 |
| DegrainMedian | zsmooth | u8 | mode=2 | 776.6 | 777.72 | 777.4 | 777.240 | 0.471 |
| DegrainMedian | dgm | u8 | mode=2 | 491.04 | 491.51 | 491.28 | 491.277 | 0.192 |
| DegrainMedian | zsmooth | u8 | mode=3 | 793.65 | 803.28 | 794.82 | 797.250 | 4.291 |
| DegrainMedian | dgm | u8 | mode=3 | 517.92 | 518.56 | 518.22 | 518.233 | 0.261 |
| DegrainMedian | zsmooth | u8 | mode=4 | 786.09 | 787.96 | 787.08 | 787.043 | 0.764 |
| DegrainMedian | dgm | u8 | mode=4 | 482.95 | 483.01 | 482.96 | 482.973 | 0.026 |
| DegrainMedian | zsmooth | u8 | mode=5 | 537.6 | 538.23 | 538.09 | 537.973 | 0.270 |
| DegrainMedian | dgm | u8 | mode=5 | 572.22 | 573.27 | 573.12 | 572.870 | 0.464 |
| DegrainMedian | zsmooth | u16 | mode=0 | 763.79 | 765.28 | 764.95 | 764.673 | 0.639 |
| DegrainMedian | dgm | u16 | mode=0 | 85.22 | 85.24 | 85.22 | 85.227 | 0.009 |
| DegrainMedian | zsmooth | u16 | mode=1 | 325.41 | 325.82 | 325.51 | 325.580 | 0.175 |
| DegrainMedian | dgm | u16 | mode=1 | 95.98 | 96.06 | 96 | 96.013 | 0.034 |
| DegrainMedian | zsmooth | u16 | mode=2 | 325.48 | 326.49 | 325.69 | 325.887 | 0.435 |
| DegrainMedian | dgm | u16 | mode=2 | 110.21 | 110.26 | 110.24 | 110.237 | 0.021 |
| DegrainMedian | zsmooth | u16 | mode=3 | 332.28 | 332.73 | 332.72 | 332.577 | 0.210 |
| DegrainMedian | dgm | u16 | mode=3 | 126.54 | 126.61 | 126.55 | 126.567 | 0.031 |
| DegrainMedian | zsmooth | u16 | mode=4 | 314.04 | 314.97 | 314.49 | 314.500 | 0.380 |
| DegrainMedian | dgm | u16 | mode=4 | 106.1 | 106.15 | 106.11 | 106.120 | 0.022 |
| DegrainMedian | zsmooth | u16 | mode=5 | 245.01 | 245.56 | 245.19 | 245.253 | 0.229 |
| DegrainMedian | dgm | u16 | mode=5 | 162.79 | 162.83 | 162.82 | 162.813 | 0.017 |
| DegrainMedian | zsmooth | f32 | mode=0 | 368.47 | 371.99 | 371.84 | 370.767 | 1.625 |
| DegrainMedian | zsmooth | f32 | mode=1 | 140.33 | 148.19 | 141.04 | 143.187 | 3.550 |
| DegrainMedian | zsmooth | f32 | mode=2 | 145.47 | 147.8 | 147.58 | 146.950 | 1.050 |
| DegrainMedian | zsmooth | f32 | mode=3 | 141.35 | 155.34 | 148.34 | 148.343 | 5.711 |
| DegrainMedian | zsmooth | f32 | mode=4 | 139.04 | 145.74 | 143.42 | 142.733 | 2.778 |
| DegrainMedian | zsmooth | f32 | mode=5 | 176.3 | 181.07 | 178.87 | 178.747 | 1.949 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 2908.19 | 2917.16 | 2909.08 | 2911.477 | 4.035 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1532.06 | 1535.22 | 1533.02 | 1533.433 | 1.323 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 1559.35 | 1604.26 | 1602.95 | 1588.853 | 20.869 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 409.22 | 409.73 | 409.61 | 409.520 | 0.218 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 1464.39 | 1464.74 | 1464.58 | 1464.570 | 0.143 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.59 | 590.52 | 590.33 | 590.147 | 0.401 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 746.03 | 747.44 | 746.81 | 746.760 | 0.577 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 400.81 | 402.1 | 401.37 | 401.427 | 0.528 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 862.46 | 863.71 | 862.57 | 862.913 | 0.565 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 549.92 | 550.6 | 550.58 | 550.367 | 0.316 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 3290.56 | 3362.8 | 3357.17 | 3336.843 | 32.808 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 622.35 | 625.39 | 625.25 | 624.330 | 1.401 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 152.6 | 152.78 | 152.62 | 152.667 | 0.081 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 1152.05 | 1154.28 | 1154.02 | 1153.450 | 0.996 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 374.22 | 374.35 | 374.29 | 374.287 | 0.053 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 96.32 | 96.5 | 96.45 | 96.423 | 0.076 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 844.7 | 848.84 | 847.63 | 847.057 | 1.738 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 143.35 | 143.43 | 143.37 | 143.383 | 0.034 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 45.06 | 45.6 | 45.07 | 45.243 | 0.252 |
| Median | zsmooth | u8 | radius=1 | 6792.74 | 6840.95 | 6823.14 | 6818.943 | 19.904 |
| Median | std | u8 | radius=1 | 5709.81 | 5838.01 | 5816.91 | 5788.243 | 56.126 |
| Median | ctmf | u8 | radius=1 | 45.55 | 45.71 | 45.67 | 45.643 | 0.068 |
| Median | zsmooth | u8 | radius=2 | 1107.57 | 1114.37 | 1110.53 | 1110.823 | 2.784 |
| Median | ctmf | u8 | radius=2 | 875 | 878.83 | 875.21 | 876.347 | 1.758 |
| Median | zsmooth | u8 | radius=3 | 246.17 | 246.41 | 246.32 | 246.300 | 0.099 |
| Median | ctmf | u8 | radius=3 | 45.88 | 45.9 | 45.89 | 45.890 | 0.008 |
| Median | zsmooth | u16 | radius=1 | 1852.11 | 1870.46 | 1867.5 | 1863.357 | 8.044 |
| Median | std | u16 | radius=1 | 1734.38 | 1752.32 | 1751.95 | 1746.217 | 8.371 |
| Median | ctmf | u16 | radius=1 | 0.77 | 0.78 | 0.77 | 0.773 | 0.005 |
| Median | zsmooth | u16 | radius=2 | 664.53 | 665.71 | 665 | 665.080 | 0.485 |
| Median | ctmf | u16 | radius=2 | 403.33 | 404.78 | 403.42 | 403.843 | 0.663 |
| Median | zsmooth | u16 | radius=3 | 161.91 | 162.21 | 162.13 | 162.083 | 0.127 |
| Median | ctmf | u16 | radius=3 | 0.17 | 0.17 | 0.17 | 0.170 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 1049.98 | 1056.65 | 1055.77 | 1054.133 | 2.959 |
| Median | std | f32 | radius=1 | 727.24 | 727.66 | 727.51 | 727.470 | 0.174 |
| Median | zsmooth | f32 | radius=2 | 211.51 | 212.04 | 211.71 | 211.753 | 0.219 |
| Median | ctmf | f32 | radius=2 | 146.05 | 146.2 | 146.15 | 146.133 | 0.062 |
| Median | zsmooth | f32 | radius=3 | 68.92 | 69.99 | 69.92 | 69.610 | 0.489 |
| RemoveGrain | zsmooth | u8 | mode=1 | 4519.87 | 4530.52 | 4529.53 | 4526.640 | 4.804 |
| RemoveGrain | rg | u8 | mode=1 | 1401.38 | 1402.59 | 1402.07 | 1402.013 | 0.496 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3223.08 | 3256.54 | 3250.57 | 3243.397 | 14.571 |
| RemoveGrain | rg | u8 | mode=4 | 910.28 | 925.77 | 917.57 | 917.873 | 6.327 |
| RemoveGrain | std | u8 | mode=4 | 5704.08 | 5857.87 | 5741.48 | 5767.810 | 65.487 |
| RemoveGrain | zsmooth | u8 | mode=12 | 5417.87 | 5470.28 | 5469.66 | 5452.603 | 24.561 |
| RemoveGrain | rg | u8 | mode=12 | 2389.01 | 2403.9 | 2390.28 | 2394.397 | 6.740 |
| RemoveGrain | std | u8 | mode=12 | 1995.79 | 2000.02 | 1995.94 | 1997.250 | 1.960 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4099.58 | 4118.22 | 4103.27 | 4107.023 | 8.059 |
| RemoveGrain | rg | u8 | mode=17 | 1256.26 | 1259.88 | 1258.83 | 1258.323 | 1.521 |
| RemoveGrain | zsmooth | u8 | mode=20 | 5436.72 | 5549.63 | 5506.75 | 5497.700 | 46.537 |
| RemoveGrain | rg | u8 | mode=20 | 774.29 | 775.74 | 775.27 | 775.100 | 0.604 |
| RemoveGrain | std | u8 | mode=20 | 2000.24 | 2006.5 | 2001.81 | 2002.850 | 2.659 |
| RemoveGrain | zsmooth | u8 | mode=22 | 5011.94 | 5031.21 | 5029.76 | 5024.303 | 8.762 |
| RemoveGrain | rg | u8 | mode=22 | 1683.47 | 1693.88 | 1684.58 | 1687.310 | 4.668 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1843.3 | 1849.78 | 1843.62 | 1845.567 | 2.982 |
| RemoveGrain | rg | u16 | mode=1 | 1166.63 | 1168.81 | 1167.7 | 1167.713 | 0.890 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1722.09 | 1726.14 | 1724.15 | 1724.127 | 1.653 |
| RemoveGrain | rg | u16 | mode=4 | 835.01 | 843.43 | 836.06 | 838.167 | 3.746 |
| RemoveGrain | std | u16 | mode=4 | 1734.21 | 1751.29 | 1748.66 | 1744.720 | 7.509 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1735.69 | 1742.04 | 1740.43 | 1739.387 | 2.695 |
| RemoveGrain | rg | u16 | mode=12 | 1481.29 | 1484.38 | 1482.75 | 1482.807 | 1.262 |
| RemoveGrain | std | u16 | mode=12 | 1323.91 | 1324.18 | 1323.94 | 1324.010 | 0.121 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1803.82 | 1811.85 | 1804.82 | 1806.830 | 3.573 |
| RemoveGrain | rg | u16 | mode=17 | 1119.47 | 1120.38 | 1120.38 | 1120.077 | 0.429 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1679.45 | 1682.65 | 1681.98 | 1681.360 | 1.378 |
| RemoveGrain | rg | u16 | mode=20 | 695.26 | 695.86 | 695.78 | 695.633 | 0.266 |
| RemoveGrain | std | u16 | mode=20 | 1320.29 | 1324.54 | 1323.4 | 1322.743 | 1.796 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1797.74 | 1816.38 | 1809.27 | 1807.797 | 7.681 |
| RemoveGrain | rg | u16 | mode=22 | 1440.75 | 1446.74 | 1443.18 | 1443.557 | 2.460 |
| RemoveGrain | zsmooth | f32 | mode=1 | 807.24 | 808.8 | 808.2 | 808.080 | 0.642 |
| RemoveGrain | rg | f32 | mode=1 | 213.5 | 213.64 | 213.62 | 213.587 | 0.062 |
| RemoveGrain | zsmooth | f32 | mode=4 | 682.48 | 693.08 | 686.96 | 687.507 | 4.345 |
| RemoveGrain | rg | f32 | mode=4 | 64.99 | 65.03 | 64.99 | 65.003 | 0.019 |
| RemoveGrain | std | f32 | mode=4 | 727.2 | 727.97 | 727.82 | 727.663 | 0.333 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1133.53 | 1145.79 | 1140.09 | 1139.803 | 5.009 |
| RemoveGrain | rg | f32 | mode=12 | 341.39 | 342.31 | 342.3 | 342.000 | 0.431 |
| RemoveGrain | std | f32 | mode=12 | 1139.07 | 1143.32 | 1142.14 | 1141.510 | 1.791 |
| RemoveGrain | zsmooth | f32 | mode=17 | 896.48 | 941.28 | 904.95 | 914.237 | 19.433 |
| RemoveGrain | rg | f32 | mode=17 | 191.4 | 191.54 | 191.48 | 191.473 | 0.057 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1164.5 | 1182.62 | 1166 | 1171.040 | 8.211 |
| RemoveGrain | rg | f32 | mode=20 | 357.96 | 358.24 | 358.23 | 358.143 | 0.130 |
| RemoveGrain | std | f32 | mode=20 | 1140.82 | 1144.07 | 1140.84 | 1141.910 | 1.527 |
| RemoveGrain | zsmooth | f32 | mode=22 | 1124.27 | 1133.5 | 1126.53 | 1128.100 | 3.928 |
| RemoveGrain | rg | f32 | mode=22 | 158.64 | 158.73 | 158.72 | 158.697 | 0.040 |
| Repair | zsmooth | u8 | mode=1 | 4279.09 | 4314.86 | 4301.39 | 4298.447 | 14.751 |
| Repair | rg | u8 | mode=1 | 1222.92 | 1223.66 | 1223.66 | 1223.413 | 0.349 |
| Repair | zsmooth | u8 | mode=12 | 3017.21 | 3025.96 | 3025.4 | 3022.857 | 3.999 |
| Repair | rg | u8 | mode=12 | 810.11 | 813.62 | 812.49 | 812.073 | 1.463 |
| Repair | zsmooth | u8 | mode=13 | 3013.75 | 3024.21 | 3020.57 | 3019.510 | 4.336 |
| Repair | rg | u8 | mode=13 | 807.9 | 820.44 | 809.24 | 812.527 | 5.622 |
| Repair | zsmooth | u16 | mode=1 | 1832.1 | 1846.15 | 1839.05 | 1839.100 | 5.736 |
| Repair | rg | u16 | mode=1 | 1123.57 | 1125.12 | 1124.25 | 1124.313 | 0.634 |
| Repair | zsmooth | u16 | mode=12 | 1697.8 | 1700.3 | 1699.73 | 1699.277 | 1.070 |
| Repair | rg | u16 | mode=12 | 775.61 | 777.72 | 776.46 | 776.597 | 0.867 |
| Repair | zsmooth | u16 | mode=13 | 1699.18 | 1703.51 | 1700.03 | 1700.907 | 1.873 |
| Repair | rg | u16 | mode=13 | 766.29 | 766.8 | 766.59 | 766.560 | 0.209 |
| Repair | zsmooth | f32 | mode=1 | 742.76 | 764.29 | 760.63 | 755.893 | 9.406 |
| Repair | rg | f32 | mode=1 | 191.86 | 192.07 | 191.95 | 191.960 | 0.086 |
| Repair | zsmooth | f32 | mode=12 | 613.7 | 628.36 | 614.18 | 618.747 | 6.800 |
| Repair | rg | f32 | mode=12 | 63.34 | 63.43 | 63.4 | 63.390 | 0.037 |
| Repair | zsmooth | f32 | mode=13 | 614.65 | 637.84 | 635.37 | 629.287 | 10.399 |
| Repair | rg | f32 | mode=13 | 63.6 | 63.78 | 63.63 | 63.670 | 0.079 |
| SmartMedian | zsmooth | u8 | radius=1 | 1636.49 | 1642 | 1641.91 | 1640.133 | 2.576 |
| SmartMedian | zsmooth | u8 | radius=2 | 547.17 | 551.28 | 547.34 | 548.597 | 1.899 |
| SmartMedian | zsmooth | u8 | radius=3 | 146.01 | 146.15 | 146.13 | 146.097 | 0.062 |
| SmartMedian | zsmooth | u16 | radius=1 | 925.58 | 926.08 | 925.92 | 925.860 | 0.208 |
| SmartMedian | zsmooth | u16 | radius=2 | 332.32 | 332.69 | 332.42 | 332.477 | 0.156 |
| SmartMedian | zsmooth | u16 | radius=3 | 91.82 | 91.95 | 91.85 | 91.873 | 0.056 |
| SmartMedian | zsmooth | f32 | radius=1 | 846.97 | 848.45 | 847.78 | 847.733 | 0.605 |
| SmartMedian | zsmooth | f32 | radius=2 | 183.6 | 183.98 | 183.79 | 183.790 | 0.155 |
| SmartMedian | zsmooth | f32 | radius=3 | 44.22 | 44.24 | 44.24 | 44.233 | 0.009 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6805.4 | 6849.66 | 6813.6 | 6822.887 | 19.225 |
| TemporalMedian | tmedian | u8 | radius=1 | 6079 | 6267.17 | 6206.73 | 6184.300 | 78.440 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2324.43 | 2349.2 | 2340.6 | 2338.077 | 10.269 |
| TemporalMedian | zsmooth | u8 | radius=10 | 960.71 | 969.47 | 968.37 | 966.183 | 3.896 |
| TemporalMedian | tmedian | u8 | radius=10 | 19.96 | 20.07 | 20.01 | 20.013 | 0.045 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.85 | 13.87 | 13.86 | 13.860 | 0.008 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1890.48 | 1893.85 | 1891.92 | 1892.083 | 1.381 |
| TemporalMedian | tmedian | u16 | radius=1 | 1702.38 | 1710.56 | 1706.98 | 1706.640 | 3.348 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 932.1 | 935.57 | 934.25 | 933.973 | 1.430 |
| TemporalMedian | zsmooth | u16 | radius=10 | 398.04 | 405.86 | 404.83 | 402.910 | 3.469 |
| TemporalMedian | tmedian | u16 | radius=10 | 17.02 | 17.37 | 17.24 | 17.210 | 0.144 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.58 | 13.74 | 13.65 | 13.657 | 0.065 |
| TemporalMedian | zsmooth | f32 | radius=1 | 929.16 | 937.53 | 930.88 | 932.523 | 3.609 |
| TemporalMedian | tmedian | f32 | radius=1 | 859.42 | 862.04 | 861.72 | 861.060 | 1.167 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 473.82 | 475.88 | 474.01 | 474.570 | 0.930 |
| TemporalMedian | zsmooth | f32 | radius=10 | 195.9 | 196.39 | 196.26 | 196.183 | 0.207 |
| TemporalMedian | tmedian | f32 | radius=10 | 17.97 | 18.33 | 18.31 | 18.203 | 0.165 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.45 | 14.49 | 14.49 | 14.477 | 0.019 |
| TemporalRepair | zsmooth | u8 | mode=0 | 6811.17 | 6864.48 | 6817.66 | 6831.103 | 23.749 |
| TemporalRepair | zsmooth | u8 | mode=1 | 940.41 | 951.28 | 950.84 | 947.510 | 5.024 |
| TemporalRepair | zsmooth | u8 | mode=2 | 995.77 | 998.63 | 998.46 | 997.620 | 1.310 |
| TemporalRepair | zsmooth | u8 | mode=3 | 1064.85 | 1071.13 | 1070.35 | 1068.777 | 2.795 |
| TemporalRepair | zsmooth | u8 | mode=4 | 6873.6 | 6890.03 | 6883.79 | 6882.473 | 6.772 |
| TemporalRepair | zsmooth | u16 | mode=0 | 1853.32 | 1859.06 | 1855.19 | 1855.857 | 2.390 |
| TemporalRepair | zsmooth | u16 | mode=1 | 1057.77 | 1064.13 | 1063.8 | 1061.900 | 2.923 |
| TemporalRepair | zsmooth | u16 | mode=2 | 975.7 | 991.92 | 977.75 | 981.790 | 7.212 |
| TemporalRepair | zsmooth | u16 | mode=3 | 946.14 | 973.64 | 952.38 | 957.387 | 11.772 |
| TemporalRepair | zsmooth | u16 | mode=4 | 1820.11 | 1826.62 | 1821.08 | 1822.603 | 2.868 |
| TemporalRepair | zsmooth | f32 | mode=0 | 870.13 | 877.09 | 876.78 | 874.667 | 3.210 |
| TemporalRepair | zsmooth | f32 | mode=1 | 455.85 | 461.24 | 456.65 | 457.913 | 2.375 |
| TemporalRepair | zsmooth | f32 | mode=2 | 451.01 | 454.14 | 453.95 | 453.033 | 1.433 |
| TemporalRepair | zsmooth | f32 | mode=3 | 490.3 | 511.37 | 504.05 | 501.907 | 8.734 |
| TemporalRepair | zsmooth | f32 | mode=4 | 765.78 | 767.45 | 766.95 | 766.727 | 0.700 |
| TemporalSoften | zsmooth | u8 | radius=1 | 4989.06 | 5029.19 | 5023.43 | 5013.893 | 17.717 |
| TemporalSoften | focus2 | u8 | radius=1 | 1624.05 | 1637.48 | 1629.71 | 1630.413 | 5.505 |
| TemporalSoften | std | u8 | radius=1 | 1684.02 | 1684.58 | 1684.5 | 1684.367 | 0.247 |
| TemporalSoften | zsmooth | u8 | radius=7 | 1215.87 | 1253.4 | 1233.05 | 1234.107 | 15.340 |
| TemporalSoften | focus2 | u8 | radius=7 | 433.24 | 433.79 | 433.59 | 433.540 | 0.227 |
| TemporalSoften | std | u8 | radius=7 | 526.82 | 530.3 | 526.87 | 527.997 | 1.629 |
| TemporalSoften | zsmooth | u16 | radius=1 | 1563.41 | 1566.99 | 1564.33 | 1564.910 | 1.518 |
| TemporalSoften | focus2 | u16 | radius=1 | 333.98 | 334.24 | 334.14 | 334.120 | 0.107 |
| TemporalSoften | std | u16 | radius=1 | 836.61 | 877.01 | 843.26 | 852.293 | 17.687 |
| TemporalSoften | zsmooth | u16 | radius=7 | 516.78 | 519.74 | 518.61 | 518.377 | 1.220 |
| TemporalSoften | focus2 | u16 | radius=7 | 124.14 | 124.61 | 124.17 | 124.307 | 0.215 |
| TemporalSoften | std | u16 | radius=7 | 318.4 | 318.69 | 318.52 | 318.537 | 0.119 |
| TemporalSoften | zsmooth | f32 | radius=1 | 936.62 | 941.2 | 940.14 | 939.320 | 1.958 |
| TemporalSoften | std | f32 | radius=1 | 613.02 | 628.43 | 614.52 | 618.657 | 6.938 |
| TemporalSoften | zsmooth | f32 | radius=7 | 273.14 | 275.46 | 274.88 | 274.493 | 0.986 |
| TemporalSoften | std | f32 | radius=7 | 209.43 | 216.86 | 215.28 | 213.857 | 3.196 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 457.55 | 458.25 | 457.62 | 457.807 | 0.315 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 163.19 | 164.04 | 163.72 | 163.650 | 0.351 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1367.19 | 1376.36 | 1373.83 | 1372.460 | 3.867 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 196.83 | 197.55 | 197.55 | 197.310 | 0.339 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 426.38 | 428.86 | 427.42 | 427.553 | 1.017 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 152.93 | 155.5 | 155.14 | 154.523 | 1.136 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 1363.85 | 1365.13 | 1364.36 | 1364.447 | 0.526 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 186.5 | 187.31 | 187.05 | 186.953 | 0.338 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 351.24 | 351.68 | 351.45 | 351.457 | 0.180 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 155.03 | 155.66 | 155.08 | 155.257 | 0.286 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 940.1 | 942.01 | 941.55 | 941.220 | 0.814 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 177.7 | 180.07 | 178.65 | 178.807 | 0.974 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 11356.27 | 11423.94 | 11384.78 | 11388.330 | 27.740 |
| VerticalCleaner | rg | u8 | mode=1 | 9082.65 | 9680.6 | 9671.67 | 9478.307 | 279.795 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 9023.06 | 9059.32 | 9058.01 | 9046.797 | 16.793 |
| VerticalCleaner | rg | u8 | mode=2 | 178.47 | 178.81 | 178.8 | 178.693 | 0.158 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2034.62 | 2053.64 | 2036.09 | 2041.450 | 8.640 |
| VerticalCleaner | rg | u16 | mode=1 | 1735.18 | 1737.93 | 1736.07 | 1736.393 | 1.146 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1994.08 | 2003.05 | 1998.36 | 1998.497 | 3.663 |
| VerticalCleaner | rg | u16 | mode=2 | 182.67 | 182.77 | 182.77 | 182.737 | 0.047 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1343.32 | 1357.15 | 1353.98 | 1351.483 | 5.916 |
| VerticalCleaner | rg | f32 | mode=1 | 1277.59 | 1281.72 | 1278.09 | 1279.133 | 1.840 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 1055.34 | 1060.41 | 1056.28 | 1057.343 | 2.202 |
| VerticalCleaner | rg | f32 | mode=2 | 92.22 | 92.25 | 92.25 | 92.240 | 0.014 |

## 0.12 - Zig 0.14.1 - AVX2
Source: BlankClip YUV420\*, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

OS: Linux fedora 6.14.9-300.fc42.x86_64 #1 SMP PREEMPT_DYNAMIC Thu May 29 14:27:53 UTC 2025 x86_64 GNU/Linux 

CPU tuning: AVX2 (x86_64_v3)

\* Some filters (CCD) require RGB input, so bit depth-specific RGB is used in those cases.

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| CCD | zsmooth | u8 | temporal_radius=0 | 165.69 | 166.16 | 166.1 | 165.983 | 0.209 |
| CCD | zsmooth | u8 | temporal_radius=3 | 22.57 | 22.57 | 22.57 | 22.570 | 0.000 |
| CCD | zsmooth | u16 | temporal_radius=0 | 96.37 | 98.78 | 98.71 | 97.953 | 1.120 |
| CCD | zsmooth | u16 | temporal_radius=3 | 5.24 | 5.24 | 5.24 | 5.240 | 0.000 |
| CCD | zsmooth | f32 | temporal_radius=0 | 159.68 | 159.93 | 159.8 | 159.803 | 0.102 |
| CCD | zsmooth | f32 | temporal_radius=3 | 31.13 | 31.21 | 31.15 | 31.163 | 0.034 |
| CCD | ccd | f32 | temporal_radius=0 | 27.48 | 27.97 | 27.94 | 27.797 | 0.224 |
| CCD | jetpack | f32 | temporal_radius=0 | 3.59 | 3.62 | 3.62 | 3.610 | 0.014 |
| Clense | zsmooth | u8 | function=Clense | 6889.55 | 6933.35 | 6900.18 | 6907.693 | 18.654 |
| Clense | rg | u8 | function=Clense | 449.63 | 449.75 | 449.65 | 449.677 | 0.052 |
| Clense | zsmooth | u8 | function=ForwardClense | 6438.86 | 6832.14 | 6724.57 | 6665.190 | 165.955 |
| Clense | rg | u8 | function=ForwardClense | 868.71 | 870.43 | 869.8 | 869.647 | 0.711 |
| Clense | zsmooth | u8 | function=BackwardClense | 6831.97 | 6849.3 | 6834.19 | 6838.487 | 7.700 |
| Clense | rg | u8 | function=BackwardClense | 869.6 | 872.38 | 870.73 | 870.903 | 1.142 |
| Clense | zsmooth | u16 | function=Clense | 1838.99 | 1859.38 | 1849.65 | 1849.340 | 8.327 |
| Clense | rg | u16 | function=Clense | 575 | 575.37 | 575.25 | 575.207 | 0.154 |
| Clense | zsmooth | u16 | function=ForwardClense | 1806.82 | 1811.16 | 1808.8 | 1808.927 | 1.774 |
| Clense | rg | u16 | function=ForwardClense | 548.63 | 548.98 | 548.8 | 548.803 | 0.143 |
| Clense | zsmooth | u16 | function=BackwardClense | 1806.55 | 1808.78 | 1807.97 | 1807.767 | 0.922 |
| Clense | rg | u16 | function=BackwardClense | 548.18 | 549.48 | 549.16 | 548.940 | 0.553 |
| Clense | zsmooth | f32 | function=Clense | 856.52 | 865.15 | 857.55 | 859.740 | 3.848 |
| Clense | rg | f32 | function=Clense | 806.53 | 809.48 | 807.24 | 807.750 | 1.257 |
| Clense | zsmooth | f32 | function=ForwardClense | 850.94 | 863.33 | 853.71 | 855.993 | 5.310 |
| Clense | rg | f32 | function=ForwardClense | 251.29 | 251.99 | 251.66 | 251.647 | 0.286 |
| Clense | zsmooth | f32 | function=BackwardClense | 859.94 | 861.43 | 860.46 | 860.610 | 0.617 |
| Clense | rg | f32 | function=BackwardClense | 251.87 | 252.28 | 251.89 | 252.013 | 0.189 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1467.75 | 1476.77 | 1472.02 | 1472.180 | 3.684 |
| DegrainMedian | dgm | u8 | mode=0 | 178.66 | 178.73 | 178.7 | 178.697 | 0.029 |
| DegrainMedian | zsmooth | u8 | mode=1 | 404.32 | 404.5 | 404.38 | 404.400 | 0.075 |
| DegrainMedian | dgm | u8 | mode=1 | 458.61 | 458.9 | 458.72 | 458.743 | 0.120 |
| DegrainMedian | zsmooth | u8 | mode=2 | 404.03 | 404.77 | 404.74 | 404.513 | 0.342 |
| DegrainMedian | dgm | u8 | mode=2 | 491.19 | 491.36 | 491.3 | 491.283 | 0.070 |
| DegrainMedian | zsmooth | u8 | mode=3 | 430.19 | 430.33 | 430.3 | 430.273 | 0.060 |
| DegrainMedian | dgm | u8 | mode=3 | 518.32 | 518.81 | 518.75 | 518.627 | 0.218 |
| DegrainMedian | zsmooth | u8 | mode=4 | 404.26 | 405.07 | 404.52 | 404.617 | 0.338 |
| DegrainMedian | dgm | u8 | mode=4 | 482.66 | 483.02 | 482.85 | 482.843 | 0.147 |
| DegrainMedian | zsmooth | u8 | mode=5 | 296.49 | 296.57 | 296.52 | 296.527 | 0.033 |
| DegrainMedian | dgm | u8 | mode=5 | 572.65 | 573.05 | 573.04 | 572.913 | 0.186 |
| DegrainMedian | zsmooth | u16 | mode=0 | 600.26 | 603.85 | 600.38 | 601.497 | 1.665 |
| DegrainMedian | dgm | u16 | mode=0 | 85.24 | 85.27 | 85.26 | 85.257 | 0.012 |
| DegrainMedian | zsmooth | u16 | mode=1 | 173.75 | 174.02 | 173.96 | 173.910 | 0.116 |
| DegrainMedian | dgm | u16 | mode=1 | 96.06 | 96.08 | 96.06 | 96.067 | 0.009 |
| DegrainMedian | zsmooth | u16 | mode=2 | 174.54 | 174.85 | 174.6 | 174.663 | 0.134 |
| DegrainMedian | dgm | u16 | mode=2 | 110.26 | 110.27 | 110.27 | 110.267 | 0.005 |
| DegrainMedian | zsmooth | u16 | mode=3 | 183.01 | 183.64 | 183.63 | 183.427 | 0.295 |
| DegrainMedian | dgm | u16 | mode=3 | 126.59 | 126.63 | 126.61 | 126.610 | 0.016 |
| DegrainMedian | zsmooth | u16 | mode=4 | 173.96 | 174.39 | 174.02 | 174.123 | 0.190 |
| DegrainMedian | dgm | u16 | mode=4 | 106.14 | 106.17 | 106.17 | 106.160 | 0.014 |
| DegrainMedian | zsmooth | u16 | mode=5 | 137.89 | 137.89 | 137.89 | 137.890 | 0.000 |
| DegrainMedian | dgm | u16 | mode=5 | 162.79 | 162.8 | 162.79 | 162.793 | 0.005 |
| DegrainMedian | zsmooth | f32 | mode=0 | 241.43 | 241.86 | 241.76 | 241.683 | 0.184 |
| DegrainMedian | zsmooth | f32 | mode=1 | 83.76 | 83.76 | 83.76 | 83.760 | 0.000 |
| DegrainMedian | zsmooth | f32 | mode=2 | 91.44 | 91.57 | 91.49 | 91.500 | 0.054 |
| DegrainMedian | zsmooth | f32 | mode=3 | 94.03 | 94.18 | 94.12 | 94.110 | 0.062 |
| DegrainMedian | zsmooth | f32 | mode=4 | 90.08 | 90.18 | 90.17 | 90.143 | 0.045 |
| DegrainMedian | zsmooth | f32 | mode=5 | 116.13 | 116.3 | 116.26 | 116.230 | 0.073 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 1416.86 | 1417.88 | 1417.76 | 1417.500 | 0.455 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1533.79 | 1534.65 | 1534.38 | 1534.273 | 0.359 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 809.12 | 809.38 | 809.26 | 809.253 | 0.106 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 408.38 | 408.86 | 408.85 | 408.697 | 0.224 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 998.35 | 998.69 | 998.5 | 998.513 | 0.139 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.67 | 589.75 | 589.69 | 589.703 | 0.034 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 444.38 | 444.78 | 444.69 | 444.617 | 0.171 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 401 | 401.91 | 401.67 | 401.527 | 0.385 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 802.68 | 806.22 | 805.47 | 804.790 | 1.523 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 385.99 | 389.15 | 387.32 | 387.487 | 1.295 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 1791.03 | 1796.8 | 1792.01 | 1793.280 | 2.521 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 372.45 | 373.79 | 372.62 | 372.953 | 0.596 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 86.35 | 86.41 | 86.4 | 86.387 | 0.026 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 692.55 | 692.67 | 692.65 | 692.623 | 0.052 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 204.37 | 204.8 | 204.53 | 204.567 | 0.177 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 51.38 | 51.45 | 51.41 | 51.413 | 0.029 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 500.57 | 500.73 | 500.64 | 500.647 | 0.065 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 87.77 | 87.8 | 87.78 | 87.783 | 0.012 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 28.77 | 28.83 | 28.78 | 28.793 | 0.026 |
| Median | zsmooth | u8 | radius=1 | 4980.15 | 5038.75 | 5005.22 | 5008.040 | 24.006 |
| Median | std | u8 | radius=1 | 5648.7 | 5815.36 | 5662.53 | 5708.863 | 75.516 |
| Median | ctmf | u8 | radius=1 | 45.61 | 45.76 | 45.7 | 45.690 | 0.062 |
| Median | zsmooth | u8 | radius=2 | 670.88 | 674.37 | 673.7 | 672.983 | 1.512 |
| Median | ctmf | u8 | radius=2 | 871.33 | 873.94 | 871.6 | 872.290 | 1.172 |
| Median | zsmooth | u8 | radius=3 | 161.19 | 162.18 | 161.84 | 161.737 | 0.411 |
| Median | ctmf | u8 | radius=3 | 45.87 | 45.95 | 45.91 | 45.910 | 0.033 |
| Median | zsmooth | u16 | radius=1 | 1660.18 | 1685.17 | 1683.76 | 1676.370 | 11.463 |
| Median | std | u16 | radius=1 | 1747.16 | 1748.84 | 1748.22 | 1748.073 | 0.694 |
| Median | ctmf | u16 | radius=1 | 0.77 | 0.77 | 0.77 | 0.770 | 0.000 |
| Median | zsmooth | u16 | radius=2 | 372.28 | 373.61 | 373.34 | 373.077 | 0.574 |
| Median | ctmf | u16 | radius=2 | 402.56 | 403.07 | 402.57 | 402.733 | 0.238 |
| Median | zsmooth | u16 | radius=3 | 96.07 | 97.53 | 97.29 | 96.963 | 0.639 |
| Median | ctmf | u16 | radius=3 | 0.17 | 0.17 | 0.17 | 0.170 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 702.23 | 707.04 | 706.07 | 705.113 | 2.077 |
| Median | std | f32 | radius=1 | 721.64 | 724.37 | 723.46 | 723.157 | 1.135 |
| Median | zsmooth | f32 | radius=2 | 137.57 | 138.34 | 137.92 | 137.943 | 0.315 |
| Median | ctmf | f32 | radius=2 | 145.4 | 145.69 | 145.51 | 145.533 | 0.120 |
| Median | zsmooth | f32 | radius=3 | 46.92 | 46.94 | 46.93 | 46.930 | 0.008 |
| RemoveGrain | zsmooth | u8 | mode=1 | 5149.34 | 5178.33 | 5152.99 | 5160.220 | 12.892 |
| RemoveGrain | rg | u8 | mode=1 | 1392.9 | 1396.29 | 1395.7 | 1394.963 | 1.479 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3679.75 | 3702.99 | 3701 | 3694.580 | 10.518 |
| RemoveGrain | rg | u8 | mode=4 | 887.08 | 902.7 | 887.21 | 892.330 | 7.333 |
| RemoveGrain | std | u8 | mode=4 | 5715.59 | 5829.79 | 5824.06 | 5789.813 | 52.536 |
| RemoveGrain | zsmooth | u8 | mode=12 | 3544.26 | 3561.99 | 3558.42 | 3554.890 | 7.657 |
| RemoveGrain | rg | u8 | mode=12 | 2205.62 | 2227.82 | 2216.23 | 2216.557 | 9.066 |
| RemoveGrain | std | u8 | mode=12 | 1989.92 | 1993.32 | 1991.1 | 1991.447 | 1.410 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4895.49 | 4921.35 | 4909.47 | 4908.770 | 10.569 |
| RemoveGrain | rg | u8 | mode=17 | 1275.69 | 1276.72 | 1276.01 | 1276.140 | 0.430 |
| RemoveGrain | zsmooth | u8 | mode=20 | 3512.01 | 3528.73 | 3513.75 | 3518.163 | 7.505 |
| RemoveGrain | rg | u8 | mode=20 | 772.67 | 773.73 | 772.69 | 773.030 | 0.495 |
| RemoveGrain | std | u8 | mode=20 | 1982.99 | 1994.23 | 1990.92 | 1989.380 | 4.716 |
| RemoveGrain | zsmooth | u8 | mode=22 | 3776.77 | 3814.47 | 3803.26 | 3798.167 | 15.807 |
| RemoveGrain | rg | u8 | mode=22 | 1731.13 | 1734.75 | 1732.12 | 1732.667 | 1.528 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1748.85 | 1780.01 | 1754.88 | 1761.247 | 13.494 |
| RemoveGrain | rg | u16 | mode=1 | 1155.95 | 1159.27 | 1156.8 | 1157.340 | 1.408 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1612.45 | 1613.34 | 1612.52 | 1612.770 | 0.404 |
| RemoveGrain | rg | u16 | mode=4 | 802.19 | 815.63 | 807.69 | 808.503 | 5.517 |
| RemoveGrain | std | u16 | mode=4 | 1748.49 | 1749.59 | 1749.27 | 1749.117 | 0.462 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1327.84 | 1331.17 | 1329.95 | 1329.653 | 1.376 |
| RemoveGrain | rg | u16 | mode=12 | 1480.49 | 1488 | 1481.96 | 1483.483 | 3.250 |
| RemoveGrain | std | u16 | mode=12 | 1322.36 | 1322.95 | 1322.62 | 1322.643 | 0.241 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1750.1 | 1756.11 | 1754.09 | 1753.433 | 2.497 |
| RemoveGrain | rg | u16 | mode=17 | 1118.54 | 1119.73 | 1119.37 | 1119.213 | 0.498 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1204.07 | 1206.44 | 1205.83 | 1205.447 | 1.005 |
| RemoveGrain | rg | u16 | mode=20 | 715.59 | 716.05 | 715.82 | 715.820 | 0.188 |
| RemoveGrain | std | u16 | mode=20 | 1320.9 | 1322.29 | 1321.77 | 1321.653 | 0.573 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1490.81 | 1492.26 | 1492.17 | 1491.747 | 0.663 |
| RemoveGrain | rg | u16 | mode=22 | 1438.84 | 1446.53 | 1445.08 | 1443.483 | 3.336 |
| RemoveGrain | zsmooth | f32 | mode=1 | 618.42 | 620.51 | 620.04 | 619.657 | 0.895 |
| RemoveGrain | rg | f32 | mode=1 | 213.53 | 213.64 | 213.59 | 213.587 | 0.045 |
| RemoveGrain | zsmooth | f32 | mode=4 | 465.61 | 467.49 | 467 | 466.700 | 0.796 |
| RemoveGrain | rg | f32 | mode=4 | 64.53 | 64.72 | 64.54 | 64.597 | 0.087 |
| RemoveGrain | std | f32 | mode=4 | 722.7 | 723.31 | 723.09 | 723.033 | 0.252 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1114.53 | 1117.04 | 1116.3 | 1115.957 | 1.053 |
| RemoveGrain | rg | f32 | mode=12 | 341.15 | 341.77 | 341.56 | 341.493 | 0.257 |
| RemoveGrain | std | f32 | mode=12 | 1132.94 | 1137.38 | 1135.21 | 1135.177 | 1.813 |
| RemoveGrain | zsmooth | f32 | mode=17 | 674.84 | 675.9 | 675.03 | 675.257 | 0.461 |
| RemoveGrain | rg | f32 | mode=17 | 191.2 | 191.25 | 191.24 | 191.230 | 0.022 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1112.4 | 1119.3 | 1116.59 | 1116.097 | 2.838 |
| RemoveGrain | rg | f32 | mode=20 | 357.79 | 358.39 | 357.97 | 358.050 | 0.251 |
| RemoveGrain | std | f32 | mode=20 | 1135.87 | 1142.63 | 1137.02 | 1138.507 | 2.953 |
| RemoveGrain | zsmooth | f32 | mode=22 | 903.68 | 907.96 | 906.25 | 905.963 | 1.759 |
| RemoveGrain | rg | f32 | mode=22 | 158.57 | 158.63 | 158.58 | 158.593 | 0.026 |
| Repair | zsmooth | u8 | mode=1 | 4767.42 | 4883.73 | 4883.68 | 4844.943 | 54.817 |
| Repair | rg | u8 | mode=1 | 1260.9 | 1267.54 | 1261.47 | 1263.303 | 3.005 |
| Repair | zsmooth | u8 | mode=12 | 3379.3 | 3392.35 | 3389.27 | 3386.973 | 5.570 |
| Repair | rg | u8 | mode=12 | 792.82 | 793.43 | 793.06 | 793.103 | 0.251 |
| Repair | zsmooth | u8 | mode=13 | 3366.52 | 3374.48 | 3371.85 | 3370.950 | 3.311 |
| Repair | rg | u8 | mode=13 | 792.84 | 827.38 | 802.4 | 807.540 | 14.562 |
| Repair | zsmooth | u16 | mode=1 | 1716.49 | 1723.4 | 1718.75 | 1719.547 | 2.877 |
| Repair | rg | u16 | mode=1 | 1126.72 | 1127.48 | 1126.74 | 1126.980 | 0.354 |
| Repair | zsmooth | u16 | mode=12 | 1515.53 | 1516.69 | 1516.04 | 1516.087 | 0.475 |
| Repair | rg | u16 | mode=12 | 758.85 | 759.69 | 758.96 | 759.167 | 0.373 |
| Repair | zsmooth | u16 | mode=13 | 1513.1 | 1515.46 | 1514.09 | 1514.217 | 0.968 |
| Repair | rg | u16 | mode=13 | 761.71 | 783.78 | 762.49 | 769.327 | 10.225 |
| Repair | zsmooth | f32 | mode=1 | 554.98 | 556.59 | 555.22 | 555.597 | 0.709 |
| Repair | rg | f32 | mode=1 | 191.79 | 191.88 | 191.84 | 191.837 | 0.037 |
| Repair | zsmooth | f32 | mode=12 | 418.67 | 418.8 | 418.75 | 418.740 | 0.054 |
| Repair | rg | f32 | mode=12 | 62.96 | 63.05 | 63.05 | 63.020 | 0.042 |
| Repair | zsmooth | f32 | mode=13 | 418.99 | 419.53 | 419.22 | 419.247 | 0.221 |
| Repair | rg | f32 | mode=13 | 63.21 | 63.34 | 63.32 | 63.290 | 0.057 |
| SmartMedian | zsmooth | u8 | radius=1 | 870.15 | 870.34 | 870.27 | 870.253 | 0.078 |
| SmartMedian | zsmooth | u8 | radius=2 | 318.34 | 318.67 | 318.39 | 318.467 | 0.145 |
| SmartMedian | zsmooth | u8 | radius=3 | 93.16 | 93.21 | 93.18 | 93.183 | 0.021 |
| SmartMedian | zsmooth | u16 | radius=1 | 440.55 | 440.72 | 440.66 | 440.643 | 0.070 |
| SmartMedian | zsmooth | u16 | radius=2 | 169.59 | 169.92 | 169.88 | 169.797 | 0.147 |
| SmartMedian | zsmooth | u16 | radius=3 | 52.98 | 53.07 | 53.06 | 53.037 | 0.040 |
| SmartMedian | zsmooth | f32 | radius=1 | 479.58 | 480.36 | 480.26 | 480.067 | 0.347 |
| SmartMedian | zsmooth | f32 | radius=2 | 105.42 | 105.59 | 105.46 | 105.490 | 0.073 |
| SmartMedian | zsmooth | f32 | radius=3 | 27.46 | 27.48 | 27.47 | 27.470 | 0.008 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6814.55 | 6878.15 | 6829.99 | 6840.897 | 27.086 |
| TemporalMedian | tmedian | u8 | radius=1 | 6038.63 | 6078.83 | 6055.19 | 6057.550 | 16.496 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2293.29 | 2327.35 | 2317.38 | 2312.673 | 14.298 |
| TemporalMedian | zsmooth | u8 | radius=10 | 914.91 | 937.69 | 928.13 | 926.910 | 9.340 |
| TemporalMedian | tmedian | u8 | radius=10 | 19.41 | 19.85 | 19.77 | 19.677 | 0.191 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.59 | 13.77 | 13.68 | 13.680 | 0.073 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1835.2 | 1848.06 | 1845.82 | 1843.027 | 5.609 |
| TemporalMedian | tmedian | u16 | radius=1 | 1705.97 | 1731.17 | 1706.85 | 1714.663 | 11.678 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 908.77 | 928.11 | 911.46 | 916.113 | 8.554 |
| TemporalMedian | zsmooth | u16 | radius=10 | 339.99 | 352.27 | 346.86 | 346.373 | 5.025 |
| TemporalMedian | tmedian | u16 | radius=10 | 16.89 | 17.15 | 17.07 | 17.037 | 0.109 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.6 | 13.62 | 13.6 | 13.607 | 0.009 |
| TemporalMedian | zsmooth | f32 | radius=1 | 870.14 | 890.47 | 875.47 | 878.693 | 8.607 |
| TemporalMedian | tmedian | f32 | radius=1 | 844.98 | 850.87 | 850.32 | 848.723 | 2.656 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 461.3 | 468.88 | 465.87 | 465.350 | 3.116 |
| TemporalMedian | zsmooth | f32 | radius=10 | 178.94 | 182.96 | 182.25 | 181.383 | 1.752 |
| TemporalMedian | tmedian | f32 | radius=10 | 17.11 | 17.76 | 17.66 | 17.510 | 0.286 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.22 | 14.28 | 14.24 | 14.247 | 0.025 |
| TemporalRepair | zsmooth | u8 | mode=0 | 6663.01 | 6804.58 | 6782.39 | 6749.993 | 62.170 |
| TemporalRepair | zsmooth | u8 | mode=1 | 1272 | 1276.14 | 1275.12 | 1274.420 | 1.761 |
| TemporalRepair | zsmooth | u8 | mode=2 | 1278.62 | 1282.4 | 1278.74 | 1279.920 | 1.754 |
| TemporalRepair | zsmooth | u8 | mode=3 | 1315.84 | 1320.74 | 1317.63 | 1318.070 | 2.024 |
| TemporalRepair | zsmooth | u8 | mode=4 | 250.26 | 250.4 | 250.34 | 250.333 | 0.057 |
| TemporalRepair | zsmooth | u16 | mode=0 | 1813.48 | 1822.47 | 1815.48 | 1817.143 | 3.854 |
| TemporalRepair | zsmooth | u16 | mode=1 | 920.23 | 921.11 | 920.74 | 920.693 | 0.361 |
| TemporalRepair | zsmooth | u16 | mode=2 | 881.9 | 883.27 | 881.97 | 882.380 | 0.630 |
| TemporalRepair | zsmooth | u16 | mode=3 | 860.03 | 866.13 | 861.73 | 862.630 | 2.570 |
| TemporalRepair | zsmooth | u16 | mode=4 | 240.82 | 242.16 | 240.91 | 241.297 | 0.612 |
| TemporalRepair | zsmooth | f32 | mode=0 | 805.99 | 845.86 | 835.47 | 829.107 | 16.887 |
| TemporalRepair | zsmooth | f32 | mode=1 | 265.48 | 269.48 | 269.2 | 268.053 | 1.823 |
| TemporalRepair | zsmooth | f32 | mode=2 | 259.24 | 260.04 | 260 | 259.760 | 0.368 |
| TemporalRepair | zsmooth | f32 | mode=3 | 365.78 | 369.95 | 368.98 | 368.237 | 1.782 |
| TemporalRepair | zsmooth | f32 | mode=4 | 534.29 | 539.27 | 539.05 | 537.537 | 2.297 |
| TemporalSoften | zsmooth | u8 | radius=1 | 3045.22 | 3069.72 | 3064.17 | 3059.703 | 10.489 |
| TemporalSoften | focus2 | u8 | radius=1 | 1628.53 | 1687.36 | 1633.27 | 1649.720 | 26.686 |
| TemporalSoften | std | u8 | radius=1 | 1665.93 | 1671.57 | 1670.71 | 1669.403 | 2.481 |
| TemporalSoften | zsmooth | u8 | radius=7 | 798.64 | 804.64 | 800.7 | 801.327 | 2.489 |
| TemporalSoften | focus2 | u8 | radius=7 | 425.98 | 432.49 | 429.5 | 429.323 | 2.661 |
| TemporalSoften | std | u8 | radius=7 | 512.8 | 521.88 | 518.63 | 517.770 | 3.756 |
| TemporalSoften | zsmooth | u16 | radius=1 | 951.12 | 953.8 | 951.7 | 952.207 | 1.151 |
| TemporalSoften | focus2 | u16 | radius=1 | 330.41 | 330.64 | 330.54 | 330.530 | 0.094 |
| TemporalSoften | std | u16 | radius=1 | 850.02 | 866.52 | 862.62 | 859.720 | 7.041 |
| TemporalSoften | zsmooth | u16 | radius=7 | 324.62 | 336.69 | 326.23 | 329.180 | 5.351 |
| TemporalSoften | focus2 | u16 | radius=7 | 122.91 | 123.39 | 122.95 | 123.083 | 0.217 |
| TemporalSoften | std | u16 | radius=7 | 311.93 | 314.36 | 314.19 | 313.493 | 1.108 |
| TemporalSoften | zsmooth | f32 | radius=1 | 898.61 | 904.28 | 899.58 | 900.823 | 2.476 |
| TemporalSoften | std | f32 | radius=1 | 605.73 | 617.88 | 606.69 | 610.100 | 5.515 |
| TemporalSoften | zsmooth | f32 | radius=7 | 224.97 | 227.25 | 226.64 | 226.287 | 0.964 |
| TemporalSoften | std | f32 | radius=7 | 206.28 | 211.83 | 208.3 | 208.803 | 2.294 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 336.07 | 336.24 | 336.13 | 336.147 | 0.070 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 161.82 | 162.48 | 161.99 | 162.097 | 0.280 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1119.17 | 1123.49 | 1120.56 | 1121.073 | 1.801 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 195.7 | 196.05 | 195.9 | 195.883 | 0.143 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 329.02 | 329.53 | 329.34 | 329.297 | 0.210 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 152.27 | 153.18 | 153.04 | 152.830 | 0.400 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 752.42 | 754.01 | 753.06 | 753.163 | 0.653 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 184.42 | 184.94 | 184.65 | 184.670 | 0.213 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 225.26 | 225.5 | 225.38 | 225.380 | 0.098 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 153.09 | 153.36 | 153.32 | 153.257 | 0.119 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 851.03 | 866.36 | 857.55 | 858.313 | 6.282 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 176.88 | 178.14 | 177.25 | 177.423 | 0.529 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 10684.97 | 10973.56 | 10946.08 | 10868.203 | 130.050 |
| VerticalCleaner | rg | u8 | mode=1 | 8770.13 | 8945.69 | 8792.16 | 8835.993 | 78.087 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 7032.39 | 7139.63 | 7121.72 | 7097.913 | 46.905 |
| VerticalCleaner | rg | u8 | mode=2 | 140.29 | 141.18 | 140.99 | 140.820 | 0.383 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2036.69 | 2060.94 | 2052.63 | 2050.087 | 10.062 |
| VerticalCleaner | rg | u16 | mode=1 | 1728.94 | 1746.2 | 1732.02 | 1735.720 | 7.516 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1875.66 | 1883.25 | 1876.93 | 1878.613 | 3.319 |
| VerticalCleaner | rg | u16 | mode=2 | 135.17 | 135.49 | 135.4 | 135.353 | 0.135 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1249.49 | 1283.95 | 1280.58 | 1271.340 | 15.511 |
| VerticalCleaner | rg | f32 | mode=1 | 1214.49 | 1248.13 | 1239.23 | 1233.950 | 14.232 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 654.87 | 663.05 | 660.93 | 659.617 | 3.466 |
| VerticalCleaner | rg | f32 | mode=2 | 91.88 | 92.03 | 92.02 | 91.977 | 0.068 |

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

## 0.10 - Zig 0.14.1 - AVX512
Source: BlankClip YUV420, 1920x1080

Machine: AMD Ryzen 9 9950X, 64 GB DDR5 6200 

OS: Linux fedora 6.14.9-300.fc42.x86_64 #1 SMP PREEMPT_DYNAMIC Thu May 29 14:27:53 UTC 2025 x86_64 GNU/Linux 

CPU tuning: AVX512 (znver4)

| Filter | Plugin | Format | Args | Min | Max | Median | Average | Standard Deviation |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Clense | zsmooth | u8 | function=Clense | 6408.27 | 6842.65 | 6810.91 | 6687.277 | 197.713 |
| Clense | rg | u8 | function=Clense | 6297.17 | 6335.14 | 6329.45 | 6320.587 | 16.720 |
| Clense | zsmooth | u8 | function=ForwardClense | 6826.37 | 6833.12 | 6831.3 | 6830.263 | 2.852 |
| Clense | rg | u8 | function=ForwardClense | 870 | 871.67 | 870.06 | 870.577 | 0.773 |
| Clense | zsmooth | u8 | function=BackwardClense | 6821.33 | 6837.11 | 6831.29 | 6829.910 | 6.516 |
| Clense | rg | u8 | function=BackwardClense | 872.95 | 873.39 | 873.25 | 873.197 | 0.184 |
| Clense | zsmooth | u16 | function=Clense | 1875.35 | 1885.98 | 1876.92 | 1879.417 | 4.685 |
| Clense | rg | u16 | function=Clense | 1469.1 | 1473.35 | 1472.66 | 1471.703 | 1.862 |
| Clense | zsmooth | u16 | function=ForwardClense | 1832.39 | 1853.63 | 1849.85 | 1845.290 | 9.251 |
| Clense | rg | u16 | function=ForwardClense | 546.06 | 546.65 | 546.3 | 546.337 | 0.242 |
| Clense | zsmooth | u16 | function=BackwardClense | 1835.1 | 1846.03 | 1839.64 | 1840.257 | 4.483 |
| Clense | rg | u16 | function=BackwardClense | 547.65 | 547.77 | 547.7 | 547.707 | 0.049 |
| Clense | zsmooth | f32 | function=Clense | 881.08 | 882.96 | 882.37 | 882.137 | 0.785 |
| Clense | rg | f32 | function=Clense | 822.62 | 823.27 | 822.71 | 822.867 | 0.288 |
| Clense | zsmooth | f32 | function=ForwardClense | 895.66 | 897.19 | 896.62 | 896.490 | 0.631 |
| Clense | rg | f32 | function=ForwardClense | 251.26 | 251.43 | 251.39 | 251.360 | 0.073 |
| Clense | zsmooth | f32 | function=BackwardClense | 895.81 | 900.11 | 898.48 | 898.133 | 1.772 |
| Clense | rg | f32 | function=BackwardClense | 251.46 | 252.72 | 252.54 | 252.240 | 0.556 |
| DegrainMedian | zsmooth | u8 | mode=0 | 1868.65 | 1877.08 | 1874.23 | 1873.320 | 3.501 |
| DegrainMedian | dgm | u8 | mode=0 | 178.63 | 178.71 | 178.7 | 178.680 | 0.036 |
| DegrainMedian | zsmooth | u8 | mode=1 | 776.43 | 777.2 | 776.89 | 776.840 | 0.316 |
| DegrainMedian | dgm | u8 | mode=1 | 458.34 | 458.48 | 458.38 | 458.400 | 0.059 |
| DegrainMedian | zsmooth | u8 | mode=2 | 775.65 | 776.14 | 775.7 | 775.830 | 0.220 |
| DegrainMedian | dgm | u8 | mode=2 | 490.29 | 490.94 | 490.61 | 490.613 | 0.265 |
| DegrainMedian | zsmooth | u8 | mode=3 | 791.5 | 792.65 | 791.89 | 792.013 | 0.478 |
| DegrainMedian | dgm | u8 | mode=3 | 515.19 | 517.82 | 517.8 | 516.937 | 1.235 |
| DegrainMedian | zsmooth | u8 | mode=4 | 787.89 | 791.74 | 789.81 | 789.813 | 1.572 |
| DegrainMedian | dgm | u8 | mode=4 | 479.69 | 482.46 | 482.39 | 481.513 | 1.290 |
| DegrainMedian | zsmooth | u8 | mode=5 | 536.18 | 536.73 | 536.48 | 536.463 | 0.225 |
| DegrainMedian | dgm | u8 | mode=5 | 571.96 | 572.9 | 572.34 | 572.400 | 0.386 |
| DegrainMedian | zsmooth | u16 | mode=0 | 761.93 | 763.08 | 762.5 | 762.503 | 0.469 |
| DegrainMedian | dgm | u16 | mode=0 | 85.19 | 85.22 | 85.2 | 85.203 | 0.012 |
| DegrainMedian | zsmooth | u16 | mode=1 | 324.65 | 325.57 | 325.32 | 325.180 | 0.388 |
| DegrainMedian | dgm | u16 | mode=1 | 95.96 | 95.97 | 95.96 | 95.963 | 0.005 |
| DegrainMedian | zsmooth | u16 | mode=2 | 324.62 | 325.92 | 325.68 | 325.407 | 0.565 |
| DegrainMedian | dgm | u16 | mode=2 | 110.13 | 110.16 | 110.14 | 110.143 | 0.012 |
| DegrainMedian | zsmooth | u16 | mode=3 | 332.4 | 332.97 | 332.7 | 332.690 | 0.233 |
| DegrainMedian | dgm | u16 | mode=3 | 126.54 | 126.58 | 126.57 | 126.563 | 0.017 |
| DegrainMedian | zsmooth | u16 | mode=4 | 315.02 | 316.03 | 315.17 | 315.407 | 0.445 |
| DegrainMedian | dgm | u16 | mode=4 | 106.05 | 106.1 | 106.06 | 106.070 | 0.022 |
| DegrainMedian | zsmooth | u16 | mode=5 | 243.03 | 243.46 | 243.3 | 243.263 | 0.177 |
| DegrainMedian | dgm | u16 | mode=5 | 162.58 | 162.65 | 162.6 | 162.610 | 0.029 |
| DegrainMedian | zsmooth | f32 | mode=0 | 366.52 | 372.89 | 367.75 | 369.053 | 2.759 |
| DegrainMedian | zsmooth | f32 | mode=1 | 139.49 | 145.59 | 141.33 | 142.137 | 2.555 |
| DegrainMedian | zsmooth | f32 | mode=2 | 145.53 | 153.5 | 146.16 | 148.397 | 3.618 |
| DegrainMedian | zsmooth | f32 | mode=3 | 146.65 | 154.55 | 149.87 | 150.357 | 3.243 |
| DegrainMedian | zsmooth | f32 | mode=4 | 140.25 | 144.37 | 142.25 | 142.290 | 1.682 |
| DegrainMedian | zsmooth | f32 | mode=5 | 184.22 | 191.58 | 188.81 | 188.203 | 3.035 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothT | 2904.28 | 2907.69 | 2904.92 | 2905.630 | 1.480 |
| FluxSmooth | flux | u8 | function=FluxSmoothT | 1531.26 | 1531.99 | 1531.82 | 1531.690 | 0.312 |
| FluxSmooth | zsmooth | u8 | function=FluxSmoothST | 1601.61 | 1603.79 | 1601.93 | 1602.443 | 0.961 |
| FluxSmooth | flux | u8 | function=FluxSmoothST | 408.8 | 409.35 | 408.98 | 409.043 | 0.229 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothT | 1458.99 | 1462.1 | 1460.97 | 1460.687 | 1.285 |
| FluxSmooth | flux | u16 | function=FluxSmoothT | 589.35 | 589.4 | 589.37 | 589.373 | 0.021 |
| FluxSmooth | zsmooth | u16 | function=FluxSmoothST | 744.37 | 745.22 | 744.6 | 744.730 | 0.359 |
| FluxSmooth | flux | u16 | function=FluxSmoothST | 401 | 401.57 | 401.16 | 401.243 | 0.240 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothT | 845.84 | 862.46 | 859.91 | 856.070 | 7.308 |
| FluxSmooth | zsmooth | f32 | function=FluxSmoothST | 532.63 | 549.48 | 541.56 | 541.223 | 6.883 |
| InterQuartileMean | zsmooth | u8 | radius=1 | 3281.55 | 3320.45 | 3289.57 | 3297.190 | 16.770 |
| InterQuartileMean | zsmooth | u8 | radius=2 | 607.74 | 611.65 | 611.46 | 610.283 | 1.800 |
| InterQuartileMean | zsmooth | u8 | radius=3 | 143.18 | 143.24 | 143.2 | 143.207 | 0.025 |
| InterQuartileMean | zsmooth | u16 | radius=1 | 1135.41 | 1146.21 | 1144.68 | 1142.100 | 4.772 |
| InterQuartileMean | zsmooth | u16 | radius=2 | 368.62 | 368.9 | 368.72 | 368.747 | 0.116 |
| InterQuartileMean | zsmooth | u16 | radius=3 | 90.51 | 91.9 | 91.85 | 91.420 | 0.644 |
| InterQuartileMean | zsmooth | f32 | radius=1 | 841.68 | 844.46 | 844.25 | 843.463 | 1.264 |
| InterQuartileMean | zsmooth | f32 | radius=2 | 142.4 | 143.13 | 143 | 142.843 | 0.318 |
| InterQuartileMean | zsmooth | f32 | radius=3 | 43.73 | 43.8 | 43.73 | 43.753 | 0.033 |
| Median | zsmooth | u8 | radius=1 | 6659.52 | 6728.25 | 6659.84 | 6682.537 | 32.324 |
| Median | std | u8 | radius=1 | 5638.74 | 5662.32 | 5655.17 | 5652.077 | 9.872 |
| Median | ctmf | u8 | radius=1 | 45.63 | 45.71 | 45.67 | 45.670 | 0.033 |
| Median | zsmooth | u8 | radius=2 | 1067.77 | 1070.33 | 1069.89 | 1069.330 | 1.118 |
| Median | ctmf | u8 | radius=2 | 872.52 | 873.65 | 872.93 | 873.033 | 0.467 |
| Median | zsmooth | u8 | radius=3 | 225.26 | 227.05 | 225.69 | 226.000 | 0.763 |
| Median | ctmf | u8 | radius=3 | 45.85 | 45.89 | 45.88 | 45.873 | 0.017 |
| Median | zsmooth | u16 | radius=1 | 1844.04 | 1852.37 | 1844.21 | 1846.873 | 3.887 |
| Median | std | u16 | radius=1 | 1725.32 | 1732.7 | 1731.77 | 1729.930 | 3.282 |
| Median | ctmf | u16 | radius=1 | 0.76 | 0.76 | 0.76 | 0.760 | 0.000 |
| Median | zsmooth | u16 | radius=2 | 641.18 | 644.65 | 641.87 | 642.567 | 1.500 |
| Median | ctmf | u16 | radius=2 | 401.81 | 405.32 | 402.29 | 403.140 | 1.554 |
| Median | zsmooth | u16 | radius=3 | 144.03 | 144.37 | 144.22 | 144.207 | 0.139 |
| Median | ctmf | u16 | radius=3 | 0.17 | 0.17 | 0.17 | 0.170 | 0.000 |
| Median | zsmooth | f32 | radius=1 | 1050.3 | 1053.5 | 1053.1 | 1052.300 | 1.424 |
| Median | std | f32 | radius=1 | 725.23 | 728.9 | 727.25 | 727.127 | 1.501 |
| Median | zsmooth | f32 | radius=2 | 210.25 | 210.64 | 210.33 | 210.407 | 0.168 |
| Median | ctmf | f32 | radius=2 | 145.57 | 145.95 | 145.87 | 145.797 | 0.164 |
| Median | zsmooth | f32 | radius=3 | 66.07 | 66.22 | 66.13 | 66.140 | 0.062 |
| RemoveGrain | zsmooth | u8 | mode=1 | 4653.12 | 4678.6 | 4653.43 | 4661.717 | 11.939 |
| RemoveGrain | rg | u8 | mode=1 | 1400.45 | 1402.68 | 1401.48 | 1401.537 | 0.911 |
| RemoveGrain | zsmooth | u8 | mode=4 | 3190.19 | 3194.29 | 3191.85 | 3192.110 | 1.684 |
| RemoveGrain | rg | u8 | mode=4 | 903.32 | 905.45 | 903.55 | 904.107 | 0.955 |
| RemoveGrain | std | u8 | mode=4 | 5658.24 | 5671.54 | 5666.14 | 5665.307 | 5.462 |
| RemoveGrain | zsmooth | u8 | mode=12 | 5444.2 | 5475.01 | 5468.02 | 5462.410 | 13.189 |
| RemoveGrain | rg | u8 | mode=12 | 2364.54 | 2376.45 | 2374.37 | 2371.787 | 5.194 |
| RemoveGrain | std | u8 | mode=12 | 1993.95 | 1997.5 | 1997.16 | 1996.203 | 1.599 |
| RemoveGrain | zsmooth | u8 | mode=17 | 4097.25 | 4182.64 | 4122.55 | 4134.147 | 35.812 |
| RemoveGrain | rg | u8 | mode=17 | 1255.74 | 1256.44 | 1255.76 | 1255.980 | 0.325 |
| RemoveGrain | zsmooth | u8 | mode=20 | 5427.35 | 5463 | 5441.12 | 5443.823 | 14.679 |
| RemoveGrain | rg | u8 | mode=20 | 772.74 | 774.01 | 773.39 | 773.380 | 0.519 |
| RemoveGrain | std | u8 | mode=20 | 1980.81 | 1996.1 | 1986.16 | 1987.690 | 6.335 |
| RemoveGrain | zsmooth | u8 | mode=22 | 4989.08 | 5030.34 | 5003.5 | 5007.640 | 17.097 |
| RemoveGrain | rg | u8 | mode=22 | 1676.59 | 1683.47 | 1681.48 | 1680.513 | 2.891 |
| RemoveGrain | zsmooth | u16 | mode=1 | 1832.53 | 1833.24 | 1833.18 | 1832.983 | 0.321 |
| RemoveGrain | rg | u16 | mode=1 | 1166.44 | 1168.4 | 1167.55 | 1167.463 | 0.803 |
| RemoveGrain | zsmooth | u16 | mode=4 | 1717.2 | 1719.84 | 1718.88 | 1718.640 | 1.091 |
| RemoveGrain | rg | u16 | mode=4 | 835.35 | 837.82 | 837.59 | 836.920 | 1.114 |
| RemoveGrain | std | u16 | mode=4 | 1727.18 | 1732.45 | 1731.67 | 1730.433 | 2.322 |
| RemoveGrain | zsmooth | u16 | mode=12 | 1741.17 | 1746.12 | 1742.74 | 1743.343 | 2.065 |
| RemoveGrain | rg | u16 | mode=12 | 1474.01 | 1480.98 | 1478.26 | 1477.750 | 2.868 |
| RemoveGrain | std | u16 | mode=12 | 1313.79 | 1322.98 | 1315.67 | 1317.480 | 3.964 |
| RemoveGrain | zsmooth | u16 | mode=17 | 1795.67 | 1796.93 | 1795.87 | 1796.157 | 0.553 |
| RemoveGrain | rg | u16 | mode=17 | 1115.73 | 1119.05 | 1115.74 | 1116.840 | 1.563 |
| RemoveGrain | zsmooth | u16 | mode=20 | 1681.82 | 1689.25 | 1688.75 | 1686.607 | 3.391 |
| RemoveGrain | rg | u16 | mode=20 | 694.43 | 694.96 | 694.51 | 694.633 | 0.233 |
| RemoveGrain | std | u16 | mode=20 | 1322.63 | 1323.54 | 1323.48 | 1323.217 | 0.416 |
| RemoveGrain | zsmooth | u16 | mode=22 | 1780.47 | 1786.75 | 1782.63 | 1783.283 | 2.605 |
| RemoveGrain | rg | u16 | mode=22 | 1435.99 | 1446.49 | 1443.46 | 1441.980 | 4.413 |
| RemoveGrain | zsmooth | f32 | mode=1 | 806.62 | 813.25 | 808.72 | 809.530 | 2.767 |
| RemoveGrain | rg | f32 | mode=1 | 213.46 | 213.57 | 213.53 | 213.520 | 0.045 |
| RemoveGrain | zsmooth | f32 | mode=4 | 670.06 | 671.14 | 670.72 | 670.640 | 0.445 |
| RemoveGrain | rg | f32 | mode=4 | 64.95 | 64.95 | 64.95 | 64.950 | 0.000 |
| RemoveGrain | std | f32 | mode=4 | 724.7 | 726.8 | 725.98 | 725.827 | 0.864 |
| RemoveGrain | zsmooth | f32 | mode=12 | 1152.61 | 1165.26 | 1161.02 | 1159.630 | 5.257 |
| RemoveGrain | rg | f32 | mode=12 | 341.76 | 342.03 | 341.98 | 341.923 | 0.117 |
| RemoveGrain | std | f32 | mode=12 | 1131.89 | 1138.9 | 1137.48 | 1136.090 | 3.026 |
| RemoveGrain | zsmooth | f32 | mode=17 | 907.54 | 917.82 | 910.75 | 912.037 | 4.294 |
| RemoveGrain | rg | f32 | mode=17 | 191.55 | 191.7 | 191.65 | 191.633 | 0.062 |
| RemoveGrain | zsmooth | f32 | mode=20 | 1164.83 | 1176.2 | 1166.36 | 1169.130 | 5.038 |
| RemoveGrain | rg | f32 | mode=20 | 358.2 | 358.35 | 358.33 | 358.293 | 0.066 |
| RemoveGrain | std | f32 | mode=20 | 1138.04 | 1138.4 | 1138.3 | 1138.247 | 0.152 |
| RemoveGrain | zsmooth | f32 | mode=22 | 1119.81 | 1122.92 | 1122.32 | 1121.683 | 1.347 |
| RemoveGrain | rg | f32 | mode=22 | 158.62 | 158.67 | 158.66 | 158.650 | 0.022 |
| Repair | zsmooth | u8 | mode=1 | 1417.1 | 1418.54 | 1417.34 | 1417.660 | 0.630 |
| Repair | rg | u8 | mode=1 | 775.41 | 777.88 | 775.68 | 776.323 | 1.106 |
| Repair | zsmooth | u8 | mode=12 | 1253.35 | 1254.7 | 1254.56 | 1254.203 | 0.606 |
| Repair | rg | u8 | mode=12 | 586.74 | 587.46 | 587.23 | 587.143 | 0.300 |
| Repair | zsmooth | u8 | mode=13 | 1251.75 | 1252.85 | 1252.33 | 1252.310 | 0.449 |
| Repair | rg | u8 | mode=13 | 588.33 | 591.87 | 590.96 | 590.387 | 1.501 |
| Repair | zsmooth | u16 | mode=1 | 953.43 | 955.82 | 955.78 | 955.010 | 1.117 |
| Repair | rg | u16 | mode=1 | 723.04 | 724.26 | 723.34 | 723.547 | 0.519 |
| Repair | zsmooth | u16 | mode=12 | 915.98 | 917.65 | 917.36 | 916.997 | 0.729 |
| Repair | rg | u16 | mode=12 | 565.38 | 566.43 | 565.64 | 565.817 | 0.446 |
| Repair | zsmooth | u16 | mode=13 | 914.96 | 916.42 | 915.3 | 915.560 | 0.624 |
| Repair | rg | u16 | mode=13 | 555.77 | 561.56 | 560.61 | 559.313 | 2.535 |
| Repair | zsmooth | f32 | mode=1 | 502.91 | 520.52 | 507 | 510.143 | 7.525 |
| Repair | rg | f32 | mode=1 | 173.08 | 173.33 | 173.3 | 173.237 | 0.111 |
| Repair | zsmooth | f32 | mode=12 | 447.95 | 451.63 | 448.28 | 449.287 | 1.662 |
| Repair | rg | f32 | mode=12 | 61.11 | 61.14 | 61.12 | 61.123 | 0.012 |
| Repair | zsmooth | f32 | mode=13 | 451.96 | 458.11 | 455.98 | 455.350 | 2.550 |
| Repair | rg | f32 | mode=13 | 61.38 | 61.43 | 61.39 | 61.400 | 0.022 |
| TemporalMedian | zsmooth | u8 | radius=1 | 6769.35 | 6810.57 | 6784.38 | 6788.100 | 17.032 |
| TemporalMedian | tmedian | u8 | radius=1 | 6302.17 | 6334.31 | 6321.48 | 6319.320 | 13.210 |
| TemporalMedian | neo_tmedian | u8 | radius=1 | 2331.18 | 2350.2 | 2342.49 | 2341.290 | 7.811 |
| TemporalMedian | zsmooth | u8 | radius=10 | 958.64 | 959.53 | 959.53 | 959.233 | 0.420 |
| TemporalMedian | tmedian | u8 | radius=10 | 20.11 | 20.28 | 20.23 | 20.207 | 0.071 |
| TemporalMedian | neo_tmedian | u8 | radius=10 | 13.82 | 13.87 | 13.87 | 13.853 | 0.024 |
| TemporalMedian | zsmooth | u16 | radius=1 | 1883.29 | 1888.3 | 1885.33 | 1885.640 | 2.057 |
| TemporalMedian | tmedian | u16 | radius=1 | 1696.34 | 1702.02 | 1699.52 | 1699.293 | 2.324 |
| TemporalMedian | neo_tmedian | u16 | radius=1 | 753.01 | 932 | 930.2 | 871.737 | 83.956 |
| TemporalMedian | zsmooth | u16 | radius=10 | 396.7 | 403.48 | 396.76 | 398.980 | 3.182 |
| TemporalMedian | tmedian | u16 | radius=10 | 17.17 | 17.47 | 17.29 | 17.310 | 0.123 |
| TemporalMedian | neo_tmedian | u16 | radius=10 | 13.69 | 13.72 | 13.7 | 13.703 | 0.012 |
| TemporalMedian | zsmooth | f32 | radius=1 | 925.28 | 935.15 | 932.92 | 931.117 | 4.226 |
| TemporalMedian | tmedian | f32 | radius=1 | 859.67 | 862.09 | 861.57 | 861.110 | 1.040 |
| TemporalMedian | neo_tmedian | f32 | radius=1 | 470.23 | 479.48 | 472.66 | 474.123 | 3.915 |
| TemporalMedian | zsmooth | f32 | radius=10 | 194.94 | 195.85 | 195.73 | 195.507 | 0.404 |
| TemporalMedian | tmedian | f32 | radius=10 | 16.95 | 17.88 | 17.65 | 17.493 | 0.396 |
| TemporalMedian | neo_tmedian | f32 | radius=10 | 14.44 | 14.5 | 14.5 | 14.480 | 0.028 |
| TemporalSoften | zsmooth | u8 | radius=1 | 4971.75 | 4991.89 | 4973 | 4978.880 | 9.214 |
| TemporalSoften | focus2 | u8 | radius=1 | 1631.9 | 1696.78 | 1636.74 | 1655.140 | 29.510 |
| TemporalSoften | std | u8 | radius=1 | 1681.64 | 1683.85 | 1683.84 | 1683.110 | 1.039 |
| TemporalSoften | zsmooth | u8 | radius=7 | 1244.44 | 1250.5 | 1250.01 | 1248.317 | 2.749 |
| TemporalSoften | focus2 | u8 | radius=7 | 432.99 | 435.36 | 435.24 | 434.530 | 1.090 |
| TemporalSoften | std | u8 | radius=7 | 526.31 | 529.99 | 529.53 | 528.610 | 1.637 |
| TemporalSoften | zsmooth | u16 | radius=1 | 1558 | 1562.68 | 1561.25 | 1560.643 | 1.958 |
| TemporalSoften | focus2 | u16 | radius=1 | 333.83 | 334.05 | 334.04 | 333.973 | 0.101 |
| TemporalSoften | std | u16 | radius=1 | 832.54 | 837.48 | 836.14 | 835.387 | 2.086 |
| TemporalSoften | zsmooth | u16 | radius=7 | 515.79 | 526.02 | 519.88 | 520.563 | 4.204 |
| TemporalSoften | focus2 | u16 | radius=7 | 124.43 | 124.47 | 124.45 | 124.450 | 0.016 |
| TemporalSoften | std | u16 | radius=7 | 318.83 | 322.25 | 319.72 | 320.267 | 1.449 |
| TemporalSoften | zsmooth | f32 | radius=1 | 936.95 | 940.4 | 938.36 | 938.570 | 1.416 |
| TemporalSoften | std | f32 | radius=1 | 610.88 | 642.98 | 616.13 | 623.330 | 14.059 |
| TemporalSoften | zsmooth | f32 | radius=7 | 273.31 | 275.71 | 273.5 | 274.173 | 1.089 |
| TemporalSoften | std | f32 | radius=7 | 203.33 | 208.63 | 207.91 | 206.623 | 2.347 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=2 | 455.86 | 457.68 | 456.64 | 456.727 | 0.746 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=2 | 163.47 | 164.06 | 163.91 | 163.813 | 0.250 |
| TTempSmooth | zsmooth | u8 | radius=1 threshold=4 mdiff=4 | 1359.3 | 1364.02 | 1360.5 | 1361.273 | 2.003 |
| TTempSmooth | ttmpsm | u8 | radius=1 threshold=4 mdiff=4 | 196.93 | 197.44 | 196.99 | 197.120 | 0.228 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=2 | 425.52 | 427.36 | 427.32 | 426.733 | 0.858 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=2 | 154.63 | 155.42 | 154.69 | 154.913 | 0.359 |
| TTempSmooth | zsmooth | u16 | radius=1 threshold=4 mdiff=4 | 1358.3 | 1361.95 | 1361.21 | 1360.487 | 1.575 |
| TTempSmooth | ttmpsm | u16 | radius=1 threshold=4 mdiff=4 | 185.16 | 185.88 | 185.46 | 185.500 | 0.295 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=2 | 351.69 | 351.94 | 351.69 | 351.773 | 0.118 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=2 | 155.41 | 155.83 | 155.57 | 155.603 | 0.173 |
| TTempSmooth | zsmooth | f32 | radius=1 threshold=4 mdiff=4 | 939.53 | 941.2 | 939.58 | 940.103 | 0.776 |
| TTempSmooth | ttmpsm | f32 | radius=1 threshold=4 mdiff=4 | 176.66 | 178.56 | 177.27 | 177.497 | 0.792 |
| VerticalCleaner | zsmooth | u8 | mode=1 | 11284.59 | 11326.66 | 11300.72 | 11303.990 | 17.330 |
| VerticalCleaner | rg | u8 | mode=1 | 9249.94 | 9347.82 | 9270.69 | 9289.483 | 42.111 |
| VerticalCleaner | zsmooth | u8 | mode=2 | 8999.44 | 9036.52 | 9005.84 | 9013.933 | 16.183 |
| VerticalCleaner | rg | u8 | mode=2 | 178.54 | 178.75 | 178.56 | 178.617 | 0.095 |
| VerticalCleaner | zsmooth | u16 | mode=1 | 2030.84 | 2036.61 | 2034.97 | 2034.140 | 2.428 |
| VerticalCleaner | rg | u16 | mode=1 | 1731.06 | 1732.65 | 1731.59 | 1731.767 | 0.661 |
| VerticalCleaner | zsmooth | u16 | mode=2 | 1991.81 | 1996.38 | 1994.19 | 1994.127 | 1.866 |
| VerticalCleaner | rg | u16 | mode=2 | 182.69 | 182.74 | 182.71 | 182.713 | 0.021 |
| VerticalCleaner | zsmooth | f32 | mode=1 | 1345.83 | 1352.89 | 1346.59 | 1348.437 | 3.164 |
| VerticalCleaner | rg | f32 | mode=1 | 1262.11 | 1276.17 | 1274.87 | 1271.050 | 6.344 |
| VerticalCleaner | zsmooth | f32 | mode=2 | 1047.93 | 1054.44 | 1051.67 | 1051.347 | 2.668 |
| VerticalCleaner | rg | f32 | mode=2 | 92.22 | 92.25 | 92.24 | 92.237 | 0.012 |

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
