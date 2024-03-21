# Zsmooth - cross-platform, cross-architecture video smoothing functions for Vapoursynth, written in Zig

**Goals**
1. Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
1. Support for 8-16 bit integer bit depths.
1. Support for 16-32 bit float bit depths. (See FP16 note below)
1. Tests for all filters, covering the scalar and vector implementations.
1. Support for RGB, YUV, and GRAY colorspaces (assuming an algorithm isn't designed for a specific color space).
1. Support Linux, Windows, and Mac.
1. Support x86_64 and aarch64 CPU architectures, with all architectures supported by the Zig compiler being possible in
   theory.
1. (Eventually) Vapoursynth and Avisynth support. (Whenever I get the spare time and motivation.)

Note: FP16 support is a work in progress. All functions support it but some are much slower than they need to be. I'm
currently suspecting that this is a bug in Zig's compiler, as explicitly processing FP16 data with FP32 operations is much faster.
The Zig compiler should really be handling this FP16->FP32 processing on its own, so I'm currently investigating the
issue.

## Implemented Features/Functions
- [x] TemporalMedian
- [x] TemporalSoften (scene detection support not yet implemented)
- [x] RemoveGrain
- [ ] Repair
- [ ] Clense
- [ ] FluxSmooth
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

* radius
  Range: 1 - 10, default: 1
  Size of the temporal window.
  The first and last *radius* frames of a clip are not filtered.

* planes
  Default: [0, 1, 2] (all planes)
  Any unfiltered planes are simply copied from the input clip.

### Temporal Soften

TemporalSoften averages radius * 2 + 1 frames. 
A pixel is included in the average only if the absolute difference between
it and the middle frame's corresponding pixel is less than the threshold.

If the scenechange parameter is greater than 0, TemporalSoften will not average
frames from different scenes.

```py
core.zsmooth.TemporalSoften(clip clip[, int radius = 4, int[] threshold = [], int scenechange = 0])
```

Parameters:

* clip
  A clip to process. 8-16 bit integer, 16-32 float bit depths and RGB, YUV, and GRAY
  colorspaces are supported.

* radius
  Range: 1 - 7, default: 4
  Size of the temporal window. This is an upper bound. At the beginning and end of the clip,
  only legally accessible frames are incorporated into the radius. So if radius if 4, then on
  the first frame, only frames 0, 1, 2, and 3 are incorporated into the result.

* threshold 
  Default: [4, 4, 4] for RGB, [4, 8, 8] for YUV, [4] for GRAY.
  Specifies the 

* scenechange
  Range: 0-255, default: 0
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

## References
The following open source software provided great inspiration and guidance, and this plugin wouldn't exist
without the hard work of their authors.

* Avisynth RemoveGrain: https://github.com/pinterf/RgTools
* Vapoursynth RemoveGrain: https://github.com/vapoursynth/vs-removegrain
* Vapoursynth TemporalSoften: https://github.com/dubhater/vapoursynth-temporalsoften2
* Vapoursynth TemporalMedian: https://github.com/dubhater/vapoursynth-temporalmedian
* Neo Temporal Median: https://github.com/HomeOfAviSynthPlusEvolution/neo_TMedian
