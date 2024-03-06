Welcome to Zmooth, home of various smoothing filters for Vapoursynth written in Zig.

Goals:
1. Clean, easy to read code, with a standard scalar (non-SIMD) implementation for every algorithm.
3. Support for 8-16 bit integer, and 16-32 bit floating point bit depths.
2. SIMD (Vectors, in Zig parlance) algorithm implementations for all supported sample types and bit depths.
4. Tests for all filters, covering the scalar and vector implementations.

TODO:
[x] TemporalMedian
[x] TemporalSoften (scene detection support not yet implemented)
[] RemoveGrain
[] FluxSmooth
[] MiniDeen
[] DegrainMedian?
[] Dogway's IQMST/IQMS functions?
[] Avisynth support?

Take a stance on internal value scaling. Current thinking is to scale internally, but provide a "scale" parameter to
disable internal scaling.

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

To generate Windows compatible DLLs with AVX512 (something like the AMD Zen 4 architecture) support:

```sh
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
