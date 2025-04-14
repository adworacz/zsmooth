# Changelog

## 0.7
* Implement Repair (from RemoveGrain).
* Performance lift is pretty impressive. On my 9950X, I'm seeing ~2-3x performance uplift over the RGVS package, and
10-20x over the RGSF output for many modes. Mode 2-4 and 5 show the most gains. Other modes (like Mode 1) "only" show an
increase of 1.5x over RGVS, but ~2-4x over RGSF. All tests were done single threaded, which provides the most consistent benchmarks.
* Add Linux binary buids for GNU (Glibc) and Musl, in both x86_64 and aarch64 variants. Similar to the
[vs-plugin-build](https://github.com/Stefan-Olt/vs-plugin-build) project, I'm targeting a very old (and thus very
compatible) version of glibc, 2.17 (released in 2012). This should ensure maximum compatibility with various
distributions. There's no significant speed penalty here, as this plugin makes *very* little use of libc functions. We
only allocate memory once for each filter instance to share filter data between the create->getFrame phase.
* Refactor RemoveGrain to simplify code using my Grid helper, which leads to some surprisingly large performance improvements.
Most RG modes are now ~4x faster than RGVS, and ~10-20x faster than RGSF. There are some exceptions, in particular modes 13-16. 
Those modes, which deal with interlaced content and thus "skip lines" (and thus wreak some havoc on branch predictors) are
either as fast or slower than RGVS. It's possible that an upgrade to newer versions of Zig (and thus the LLVM
compiler/optimizer) will improve this, but right now performance is sub-par. However, these modes are rarely (if
ever?) actually used in the wild, so I'm not sweating it right now.
* Updated Repair to process all edge pixels using a "mirror" based algorithm. This is different than other
RemoveGrain/Repair implementations which simply skip (copy) edge pixels. This came out of a direct request from the
community: https://github.com/adworacz/zsmooth/issues/6

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
