# Zsmooth - cross-platform, cross-architecture video smoothing functions for Vapoursynth, written in Zig

**Goals**
* Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
* Support for 8-16 integer, and 16-32 float bit depths. (See FP16 note below)
* Tests for all filters, covering the scalar and vector implementations.
* Support for RGB, YUV, and GRAY colorspaces (assuming an algorithm isn't designed for a specific color space).
* Support Linux, Windows, and Mac.
* Support x86_64 and aarch64 CPU architectures, with all architectures supported by the Zig compiler being possible in theory.
* (Eventually) Vapoursynth and Avisynth support. (Whenever I get the spare time and motivation.)

Note: FP16 support is a work in progress. All functions support it but some are much slower than they need to be. I'm
currently suspecting that this is a bug in Zig's compiler, as explicitly processing FP16 data with FP32 operations is much faster.
The Zig compiler should really be handling this FP16->FP32 processing on its own, so I'm currently investigating the
issue.

## Implemented Features/Functions
- [x] TemporalMedian
- [x] TemporalSoften
- [x] RemoveGrain
- [x] FluxSmooth
- [ ] Repair
- [ ] Clense
- [ ] MiniDeen
- [ ] CCD
- [ ] Dogway's IQMST/IQMS functions
- [ ] Avisynth support

## Function Documentation
### Temporal Median
TemporalMedian is a temporal denoising filter. It replaces every pixel with the median of its temporal neighbourhood.

This filter will introduce ghosting, so use with caution.

```py
core.zsmooth.TemporalMedian(clip clip[, int radius = 1, int[] planes = [0, 1, 2]])
```

Parameters:
* clip
  A clip to process. 8-16 bit integer, 16-32 float bit depths and RGB, YUV, and GRAY
  colorspaces are supported.

* radius = 1
  Range: 1 - 10
  Size of the temporal window. Full SIMD acceleration for *all* radii :D. 
  The first and last *radius* frames of a clip are not filtered.

* planes = [0, 1, 2] (all planes)
  Any unfiltered planes are simply copied from the input clip.

### Temporal Soften

TemporalSoften averages radius * 2 + 1 frames. 
A pixel is included in the average only if the absolute difference between
it and the middle frame's corresponding pixel is less than the threshold.

If the scenechange parameter is greater than 0, TemporalSoften will not average
frames from different scenes.

```py
core.zsmooth.TemporalSoften(clip clip[, int radius = 4, float[] threshold = [], int scenechange = 0, bool scalep=False])
```

Parameters:

* clip
  A clip to process. 8-16 bit integer, 16-32 float bit depths and RGB, YUV, and GRAY
  colorspaces are supported.

* radius = 4
  Range: 1 - 7
  Size of the temporal window. This is an upper bound. At the beginning and end of the clip,
  only legally accessible frames are incorporated into the radius. So if radius if 4, then on
  the first frame, only frames 0, 1, 2, and 3 are incorporated into the result.

* threshold = [4, 4, 4] for RGB, [4, 8, 8] for YUV, [4] for GRAY.
  If the difference between the pixel in the current frame and any of its temporal neighbors is less than this
  threshold, it will be included in the mean. If the difference is greater, it will not be included in the mean.  
  If set to 0, the plane is copied from the source.

* scalep = False
  Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255)
  to the corresponding range of the input clip's bit depth.

* scenechange = 0
  Range: 0-255
  Calculated as a percent internally (scenechange/255) to qualify if a frame is a scenechange or not.
  Currently requires the SCDetect filter from the Miscellaneous filters plugin, but
  future plans include specifying custom scene change properties to accomidate other
  scene change detection mechanisms.

### RemoveGrain 

RemoveGrain is a spatial denoising filter.

Modes 0-24 are implemented. Different modes can be
specified for each plane. If there are fewer modes than planes, the last
mode specified will be used for the remaining planes.

**Note on RGSF differences**: 
This plugin operates slightly differently than RGSF, the 'single precision' floating
point Vapoursynth implementation of RemoveGrain. Specifically, RGSF isn't actually 'single precision' -
it's double precision. Even for operations that don't benefit from increased floating point precision.
This means that RGSF is actually significantly slower than it needs to be for some/most operations.

The implementation in this plugin properly uses single precision floating point for all modes.
This is exactly the same approach that the Avisynth version of RgTools takes. It does mean that
for some operations, the output will very sligtly differ between RGSF and this plugin, as RGSF is
technically doing higher precision (but much slower) calculations.

```py
core.zsmooth.RemoveGrain(clip clip, int[] mode)
```

Parameters:
* clip
  A clip to process. 8-16 bit integer, 16-32 float bit depths and RGB, YUV, and GRAY
  colorspaces are supported.

* mode
  Required, no default.
  For a description of each mode, see the docs from the original Vapoursynth documentation here:
  https://github.com/vapoursynth/vs-removegrain/blob/master/docs/rgvs.rst

### FluxSmooth(S|ST)
```py
core.zsmooth.FluxSmoothT(clip clip, float[] temporal_threshold = 7, bool scalep=False)
core.zsmooth.FluxSmoothST(clip clip, float[] temporal_threshold = 7, float[] spatial_threshold = 7, bool scalep = False)
```

FluxSmoothT (**T**\ emporal) examines each pixel and compares it to the corresponding pixel
in the previous and next frames. Smoothing occurs if both the previous frame's value and the next frame's value are greater,
or if both are less, than the value in the current frame. 

Smoothing is done by averaging the pixel from the current frame with the pixels from the previous and/or next frames, if they are within *temporal_threshold*.

FluxSmoothST (**S**\ patio\ **T**\ emporal) does the same as FluxSmoothT, except the pixel's eight neighbours from 
the current frame are also included in the average, if they are within *spatial_threshold*.

The first and last rows and the first and last columns are not processed by FluxSmoothST.

Parameters:
* clip
  A clip to process. 8-16 bit integer, 16-32 float bit depths and RGB, YUV, and GRAY
  colorspaces are supported.

* temporal_threshold = 7
  Temporal neighbour pixels within this threshold from the current pixel are included in the average.
  Can be specified as an array, with values corresonding to each plane of the input clip.
  A negative value (such as -1) indicates that the plane should not be processed and will be copied from the input clip.

* spatial_threshold = 7 
  Spatial neighbour pixels within this threshold from the current pixel are included in the average.
  A negative value (such as -1) indicates that the plane should not be processed and will be copied from the input clip.

* scalep = False
  Parameter scaling. If set to true, all threshold values will be automatically scaled from 8-bit range (0-255)
  to the corresponding range of the input clip's bit depth.

## Building
All build artifacts are placed under `zig-out/lib`.

### Native builds
To build for the operating system and architecture of the current machine:

```sh
zig build -Doptimize=ReleaseFast
```

### Cross-compiling
Zig has excellent cross-compilation support, letting us create Windows, Mac, or Linux compatible libraries from any of
those same operating systems and architectures.

To generate Windows compatible DLLs, with AVX2 support:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v3
```

To generate Windows compatible DLLs with AVX512 support:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=x86_64_v4
# or the following for specific targeting of AMD Zen4 CPUs
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows -Dcpu=znver4
```

See https://en.wikipedia.org/wiki/AVX-512#CPUs_with_AVX-512 for a better breakdown on which CPUs support AVX512
features.

To generate Mac (x86_64) compatible libraries:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-macos
```

To generate Mac (aarch64) ARM compatible libraries:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos 
```

To generate Mac (aarch64) ARM compatible libraries for a specific CPU (like M1, M2, etc):

```sh
zig build -Doptimize=ReleaseFast -Dtarget=aarch64-macos -Dcpu=apple_m1
```

Use `zig targets` to see an exhaustive list of all architectures, CPUs, and operating systems that Zig supports.

## Benchmarks
These are just some rough benchmarks for now. A more comprehensive set of benchmarks will come in the future.

All benchmarks were taken on a AMD Ryzen Threadripper 3960x, with 128GB DDR4 3600Mhz RAM, on Archlinux, CPU Governor set
to `performance`, running a library produced with `zig build -Doptimize=ReleaseFast`.

Clip is generated from `BlankClip`, 1920x1080, in RGB, in the bit depth specified.

FPS taken from the best of 3 runs.

### TemporalMedian
Plugin version: 0.1

8 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 1 | 1647 | 
| Tmedian | Radius 1 | 1645 | 
| Neo_Tmedian | Radius 1 | 1742| 
| Zsmooth | Radius 4 | 953 | 
| Tmedian | Radius 4 | 180 | 
| Neo_Tmedian | Radius 4 |907| 
| Zsmooth | Radius 10 | 112 | 
| Tmedian | Radius 10 | 69 | 
| Neo_Tmedian | Radius 10 | 57 | 

16 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 1 | 838 | 
| Tmedian | Radius 1 | 843 | 
| Neo_Tmedian | Radius 1 | 841 | 
| Zsmooth | Radius 4 | 468 | 
| Tmedian | Radius 4 | 135 | 
| Neo_Tmedian | Radius 4 | 451 | 
| Zsmooth | Radius 10 | 95 | 
| Tmedian | Radius 10 | 49 | 
| Neo_Tmedian | Radius 10 | 56  | 

16 bit float, 16 threads
(Tmedian and Neo_Tmedian don't support FP16)

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 1 | 478 | 
| Zsmooth | Radius 4 | 77 | 
| Zsmooth | Radius 10 | 67 | 

32 bit float, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 1 | 421 | 
| Tmedian | Radius 1 | 422 | 
| Neo_Tmedian | Radius 1 | 424 | 
| Zsmooth | Radius 4 | 228 | 
| Tmedian | Radius 4 | 159 | 
| Neo_Tmedian | Radius 4 | 223 | 
| Zsmooth | Radius 10 | 79 | 
| Tmedian | Radius 10 | 52 | 
| Neo_Tmedian | Radius 10 | 52 | 

### TemporalSoften
Plugin Version: 0.1

8 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 7 | 517 | 
| TemporalSoften2 | Radius 7 | 581 | 

16 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 7 | 311 | 
| TemporalSoften2 | Radius 7 | 266 | 

16 bit float, 16 threads
TemporalSoften2 doesn't support FP16

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 7 | 315 | 

32 bit float, 16 threads
TemporalSoften2 doesn't support FP32

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Radius 7 | 155 | 

### RemoveGrain
Plugin Version: 0.1

8 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Mode 1 | 2230 | 
| RGVS/RGSF | Mode 1 | 2298 | 
| Zsmooth | Mode 4 | 2236 | 
| RGVS/RGSF | Mode 4 | 2224 | 
| std.Median | Mode 4 | 2270 | 
| Zsmooth | Mode 11 | 2340 | 
| RGVS/RGSF | Mode 11 | 2259 | 
| std.Convolution | Mode 11 | 2232 | 

16 bit integer, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Mode 1 | 1153 | 
| RGVS/RGSF | Mode 1 | 1152 | 
| Zsmooth | Mode 4 | 1155 | 
| RGVS/RGSF | Mode 4 | 1144 | 
| std.Median | Mode 4 | 1145 | 
| Zsmooth | Mode 11 | 1154 | 
| RGVS/RGSF | Mode 11 | 1157 | 
| std.Convolution | Mode 11 | 1156 | 

32 bit float, 16 threads

| Plugin | Parameters | FPS |
| --- | --- |  --- |
| Zsmooth | Mode 1 | 577 | 
| RGVS/RGSF | Mode 1 | 578| 
| Zsmooth | Mode 4 | 578 | 
| RGVS/RGSF | Mode 4 | 206 | 
| std.Median | Mode 4 | 580 | 
| Zsmooth | Mode 11 | 578 | 
| RGVS/RGSF | Mode 11 | 579 | 
| std.Convolution | Mode 11 | 578 | 

## References
The following open source software provided great inspiration and guidance, and this plugin wouldn't exist
without the hard work of their authors.

* Avisynth RemoveGrain: https://github.com/pinterf/RgTools
* Vapoursynth RemoveGrain: https://github.com/vapoursynth/vs-removegrain
* Vapoursynth TemporalSoften: https://github.com/dubhater/vapoursynth-temporalsoften2
* Vapoursynth TemporalMedian: https://github.com/dubhater/vapoursynth-temporalmedian
* Neo Temporal Median: https://github.com/HomeOfAviSynthPlusEvolution/neo_TMedian
