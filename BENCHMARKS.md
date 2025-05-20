# Benchmarks
All benchmarks are run single-threaded (`core.num_threads = 1`) with a max cache size of 1GB (`core.max_cache_size = 1024`) 
to provided the greatest stability of FPS numbers between runs. 

So while the benchmarks show fast results, you'll see even faster by using Zsmooth when using a fully threaded VapourSynth script.

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
