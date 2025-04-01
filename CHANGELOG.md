# Changelog

## 0.7
* Implement Repair (from RemoveGrain).
* Performance lift is pretty impressive. On my 9950X, I'm seeing ~2-3x performance uplift over the RGVS package, and
10-20x over the RGSF output for many modes. Mode 2-4 and 5 show the most gains. Other modes (like Mode 1) "only" show an
increase of 1.5x over RGVS, but ~2-4x over RGSF. All tests were done single threaded, which provides the most consistent benchmarks.

## 0.6
* Add DegrainMedian implementation.
* Optimize TemporalMedian even more. Latest tests show a bump from 340fps to 413fps in 
  single core tests on my laptop. Essentially I heavily reduced branching calculations by
  moving diameter calculations to comptime. This does blow up the size of the binary by about double,
  from about 850kB to 1.6MB, but oh well.
* Refactored internal common code significantly, and introduced a helper type called Grid for operating on a 3x3
  grid of pixels as either scalars or vectors.
* Added more testing to many of the common functions.
* Add generic builds for Mac OS, on x86_64 and aarch64 architectures.

## 0.5
* Final fixes for stride related issues, as reported in https://github.com/adworacz/zsmooth/issues/1
* Fixes implemented in TemporaMedian, TemporalSoften, and FluxSmooth. RemoveGrain was not effected.

## 0.4
* More fixes for stride handling, this time for high bit depth content. I was missing a divide.
* Change all filters to use slices instead of multi-pointers. Provides proper runtime safety checks in Debug mode.

## 0.3
Fixed:
* Use of stride in all filters. I made some incorrect assumptions about being able to ignore stride,
  as Vapoursynth aligns frame allocations to 32-byte (sometimes 64-byte) boundaries, so video like 720x480p was
  broken with my prior implementation.
* Also fixed SIMD vector width calculations, which was causing my vector-based calculations to be off for certain frame
  sizes (like 720x480).

## 0.2
Major changes:
* Add FluxSmooth support
* Substantially improve the performance of TemporalSoften
* Update TemporalMedian to use compile-time generated sorting networks,
  which also leads to execellent performance for all radii.
* Add `scalep` support to all filters, for optional parameter scaling.
* Implement RG Mode 24 (which I missed in v0.1)
* General code cleanup
* More unit tests
* Refactored the README a bit with tables to improve readability.

## 0.1
Initial release.

1. Implemented TemporalMedian
1. Implemented TemporalSoften
1. Implemented all RemoveGrain modes.
1. Implemented support for 8-16 bit integer, and 16-32 bit float in all plugins.
1. Support RBG, YUV, and GRAY in all plugins.
