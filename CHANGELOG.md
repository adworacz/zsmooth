# Changelog

## 0.12
* Migrate Median and InterQuartileMean to ZAPI and compartmentalized filter modules to reduce binary
size, improve compatibility, and surprisingly slightly improve performance.
* Fix bug in Median and InterQuartileMean where radii values passed as an array were not respected properly (only the
first value was used.)
* Add SmartMedian - a median thresholded based on variance. Honestly, I really like the results of this one.
* Add TemporalRepair, from RGTools. Consider this experimental, as I have nothing to compare against in the Vapoursynth
world, so the output may be slightly different (buggy) than the Avisynth version. Please file an issue for any
differences found.

## 0.11
* Fix default radius for InterQuartileMean and Median.

## 0.10
* Minor code improvements to FluxSmooth, no change in output/speed.
* Minor code improvements to TemporalMedian, seems like a minor boost in speed.
* Minor code improvements to TemporalSoften, no change in output/speed.
* Enable float "fast-math" for all filters, with a build option for easily switching back to "strict" mode. This brings some performance
  benefits for float formats, at the cost of a potential loss in accuracy. I believe this is an acceptable tradeoff for 
  image processing (this isn't scientific computing). VerticalCleaner seems to be the most positively impacted in terms of
  speed in my benchmarks, but my benchmarks don't use real video so there's little possibility for "subnormals"/"denormals" 
  (aka, floats close to zero but not exactly zero) which can have significant performance impacts without fast math.
* Implement InterQuartileMean radius 2 (5x5 grid).
* Implement InterQuartileMean radius 3 (7x7 grid).
* Significantly speedup InterQuartileMean radius 1 (3x3 grid) with hand written vector version.
* Support disabling processing in InterQuartileMean via `planes` param, or by passing 0 to `radius`.
* Upgrade to Zig 0.14.1
* Implement Median, with support for radius 0-3.

## 0.9
* Add implementation of InterQuartileMean, as made popular by Dogway. Just IQM3 (3x3) support for now, 5x5 will come later.
* Implement TTempSmooth. As per usual, it's faster than the original, anywhere from 2.7x-5x depending on the use case
and the machine running the code.
* Support -1 for `scenechange` parameter in TemporalSoften, which enables reuse of existing scene change 
properties instead of calling SCDetect from Misc filters internally.
* Add `planes` parameter to FluxSmooth, closing a compatibility gap with the original plugin.
Request came from Selur: https://github.com/adworacz/zsmooth/issues/3
* Fix bug in Clense with `next` clip dependencies.
* Upgraded to Zig 0.14.0
* Fix built zips to not include the zig build path in the final zip file any more. This was my mistake and it shouldn't
have happened. All zips should just have the library file now with no directory structure. Sorry about that.
* Fixed build script to work with Zig 0.14.0 and windows builds.
* Changed zip names so that AVX512 (znver4) build is tagged with `znver4` at the end instead of the beginning of the
file name. Should visually sort artifact names better from now on.
* Add AVX512 (znver4) builds for Linux (GNU and Musl).
* Add BENCHMARKS.md to track performance.

## 0.8
* Fix bug pertaining to scene change handling in TemporalSoften. It had a typo in the scene change property names so 
scene change handling was effectively broken.
* Cleaned up / unified build artifact names. The new names for the zips make a lot more sense (to me at least), and
should simplify the lives of package managers. I'm open to feedback / suggestions on a better naming scheme, but this
was the best I could think of on short notice.
* Standardize AVX2 as the default build for x86_64 binaries. 

## 0.7
* Implement Repair (from RemoveGrain). Performance lift is pretty impressive. On my 9950X, I'm seeing ~2-3x performance uplift over the RGVS package, and
10-20x over the RGSF output for many modes. Mode 2-4 and 5 show the most gains. Other modes (like Mode 1) "only" show an
increase of 1.5x over RGVS, but ~2-4x over RGSF. All tests were done single threaded, which provides the most consistent benchmarks.
* Add Linux binary buids for GNU (Glibc) and Musl, in both x86_64 and aarch64 variants. Similar to the
[vs-plugin-build](https://github.com/Stefan-Olt/vs-plugin-build) project, I'm targeting a very old (and thus very
compatible) version of glibc, 2.17 (released in 2012). This should ensure maximum compatibility with various
distributions. There's no significant speed penalty here, as this plugin makes *very* little use of libc functions. We
only allocate memory once for each filter instance to share filter data between the create->getFrame phase.
* Refactor RemoveGrain to simplify code using my Grid helper, which leads to some surprisingly large performance improvements.
Most RG modes are now ~4x faster than RGVS, and ~10-20x faster than RGSF. There are some exceptions, in particular modes 13-16. 
Those modes, which deal with interlaced content and thus "skip lines" (and thus wreak havoc on branch predictors) are
either as fast or slower than RGVS. It's possible that an upgrade to newer versions of Zig (and thus the LLVM
compiler/optimizer) will improve this, but right now performance is sub-par. However, these modes are rarely (if
ever?) actually used in the wild, so I'm not sweating it right now.
* Updated Repair to process all edge pixels using a "mirror" based algorithm. This is different than other
RemoveGrain/Repair implementations which simply skip (copy) edge pixels. This came out of a direct request from the
community: https://github.com/adworacz/zsmooth/issues/6
* Update RemoveGrain to process all edge pixels using a "mirror" based algorithm, just like Repair.
* Implement VerticalCleaner (from RemoveGrain). As always, a bit of a speed boost over RGVS/RGSF. For Mode 1, 8-bit RGB single-threaded content 
on my 9950X, I'm seeing ~7000fps (Zsmooth) vs ~4100 (RGVS). For 32-bit RGB content, I'm seeing \~680 fps (Zsmooth) vs
\~588 fps (RGSF), so less of a perf boost but still a boost. Mode 2 sees a *significant* speed boost - for 8-bit RGB
content, I'm seeing \~4000fps (Zsmooth) and \~88 fps (RGVS). No that's not a typo. For 32-bit content I'm seeing
\~333 fps (Zsmooth) and \~33 fps (RGSF). So about 10x over RGSF.
* Implement Clense. For 8-bit RGB, single threaded, \~2800 fps (Zsmooth) vs \~243 fps (RGVS). For 32-bit, \~393 fps (Zsmooth) vs \~370
fps (RGSF). So about 10x faster than RGVS, but about the same for RGSF.
* Implement Forward/BackwardClense. For 8-bit RGB, single-threaded, \~2800 fps (Zsmooth) vs \~177 fps (RGVS). For
32-bit, \~400 fps (Zsmooth) vs \~128 fps (RGSF). So ~20x faster than RGVS, and ~3x faster than RGSF.

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
