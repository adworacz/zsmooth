Welcome to Zsmooth, home of various smoothing filters for Vapoursynth written in Zig.

Goals:
1. Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
1. Support for 8-16 bit integer bit depths.
1. Support for 16-32 bit float bit depths.
1. Tests for all filters, covering the scalar and vector implementations.
1. Support for RGB, YUV, and GREY colorspaces (assuming an algorithm isn't designed for a specific color space).

## Implemented Functions
* [x] TemporalMedian
* [x] TemporalSoften (scene detection support not yet implemented)
* [x] RemoveGrain
* [] Repair
* [] Cleanse
* [] FluxSmooth
* [] MiniDeen
* [] CCD
* [] Dogway's IQMST/IQMS functions
* [] Avisynth support

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

To generate Windows compatible DLLs:

```sh
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-windows
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
